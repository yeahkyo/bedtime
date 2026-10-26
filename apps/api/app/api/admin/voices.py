"""Admin CRUD for voice catalog (global system presets + per-user clones)."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.user import User
from app.models.voice import Voice
from app.providers.factory import get_tts_provider
from app.services.errors import safe_error_message
from app.services.narration_prosody import synthesize_with_prosody
from app.services.provider_settings import (
    SPEECH_PROVIDERS,
    env_speech_model,
    resolve_speech_model,
)
from app.services.storage import storage_service
from app.services.voice_settings import (
    clamp_speed,
    resolve_voice_settings,
    tier_for_speed,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voices", tags=["admin-voices"])

_PREVIEW_TEXT_ZH = "夜深了，星星轻轻眨眼。我们听一个很软的故事，慢慢地，安心地，准备入睡。"
_PREVIEW_TEXT_EN = "Night is soft and quiet. Let's listen to a gentle story, and slowly drift to sleep."
_PREVIEW_TEXT_MAX = 500


class AdminVoiceOut(BaseModel):
    id: int
    user_id: int | None = None
    user_display_name: str | None = None
    name: str
    description: str | None = None
    kind: str
    language: str
    provider: str
    provider_voice_id: str
    speech_model: str | None = None
    speed: float = 1.0
    enabled: bool = True
    sort_order: int = 0
    preview_text: str | None = None
    preview_audio_url: str | None = None
    preview_generated_at: str | None = None
    created_at: str | None = None


class AdminVoiceListOut(BaseModel):
    items: list[AdminVoiceOut]
    total: int
    page: int
    page_size: int
    speech_providers: list[str]
    env_models: dict[str, str]


class AdminVoiceUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=64)
    description: str | None = None  # empty string clears
    kind: str | None = None
    language: str | None = Field(default=None, max_length=8)
    provider: str | None = None
    provider_voice_id: str | None = Field(default=None, max_length=128)
    speech_model: str | None = None  # empty string clears override
    speed: float | None = Field(default=None, ge=0.5, le=2.0)
    enabled: bool | None = None
    sort_order: int | None = Field(default=None, ge=-9999, le=99999)


class AdminVoiceCreate(BaseModel):
    """system → global catalog (user_id ignored). clone → requires user_id."""

    user_id: int | None = None
    name: str = Field(min_length=1, max_length=64)
    description: str | None = Field(default=None, max_length=200)
    kind: str = "system"
    language: str = "zh"
    provider: str
    provider_voice_id: str = Field(min_length=1, max_length=128)
    speech_model: str | None = None
    speed: float = Field(default=1.0, ge=0.5, le=2.0)
    enabled: bool = True
    sort_order: int = Field(default=0, ge=-9999, le=99999)


class AdminVoicePreviewIn(BaseModel):
    """Ad-hoc live preview (unsaved form) or overrides for generate."""

    provider: str | None = None
    provider_voice_id: str | None = None
    speech_model: str | None = None
    language: str | None = None
    speed: float | None = Field(default=None, ge=0.5, le=2.0)
    text: str | None = Field(default=None, max_length=_PREVIEW_TEXT_MAX)


class AdminVoicePreviewGenerateIn(BaseModel):
    """Generate and persist a preview clip for a saved voice."""

    text: str | None = Field(default=None, max_length=_PREVIEW_TEXT_MAX)


def _default_preview_text(language: str | None) -> str:
    lang = (language or "zh").strip().lower()
    if lang.startswith("en"):
        return _PREVIEW_TEXT_EN
    return _PREVIEW_TEXT_ZH


def _preview_storage_key(voice_id: int) -> str:
    return f"voices/{voice_id}/preview.mp3"


async def _synthesize_preview(
    *,
    provider: str,
    provider_voice_id: str,
    speech_model: str | None,
    language: str | None,
    text: str | None,
    speed: float | None = None,
) -> tuple[bytes, str]:
    name = (provider or "").strip().lower()
    if name not in SPEECH_PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Invalid provider: {provider}")
    voice_id = (provider_voice_id or "").strip()
    if not voice_id:
        raise HTTPException(status_code=400, detail="provider_voice_id is required")
    sample = (text or "").strip() or _default_preview_text(language)
    if len(sample) > _PREVIEW_TEXT_MAX:
        sample = sample[:_PREVIEW_TEXT_MAX]
    model = await resolve_speech_model(name, voice_model=speech_model)
    vs = resolve_voice_settings(speed=clamp_speed(speed if speed is not None else 1.0))
    tts = get_tts_provider(name)
    try:
        synth = await synthesize_with_prosody(
            tts,
            sample,
            voice_id,
            vs,
            speech_provider=name,
            model=model or None,
        )
        audio = synth.audio
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("admin voice preview failed provider=%s voice=%s", name, voice_id)
        raise HTTPException(
            status_code=502,
            detail=safe_error_message(exc, fallback="Voice preview failed"),
        ) from exc
    if not audio:
        raise HTTPException(status_code=502, detail="Voice preview returned empty audio")
    return audio, sample


async def _to_out(voice: Voice, user: User | None = None) -> AdminVoiceOut:
    preview_url: str | None = None
    key = (voice.preview_object_key or "").strip()
    if key:
        try:
            preview_url = await storage_service.presigned_url(key)
        except Exception:
            logger.warning("preview url failed voice_id=%s key=%s", voice.id, key, exc_info=True)
            preview_url = None
    desc = (getattr(voice, "description", None) or "").strip() or None
    return AdminVoiceOut(
        id=voice.id,
        user_id=voice.user_id,
        user_display_name=user.display_name if user else None,
        name=voice.name,
        description=desc,
        kind=voice.kind,
        language=voice.language or "zh",
        provider=voice.provider or "",
        provider_voice_id=voice.provider_voice_id or "",
        speech_model=voice.speech_model,
        speed=clamp_speed(getattr(voice, "speed", None)),
        enabled=bool(getattr(voice, "enabled", True)),
        sort_order=int(getattr(voice, "sort_order", 0) or 0),
        preview_text=voice.preview_text,
        preview_audio_url=preview_url,
        preview_generated_at=(
            voice.preview_generated_at.isoformat() if voice.preview_generated_at else None
        ),
        created_at=voice.created_at.isoformat() if voice.created_at else None,
    )


@router.get("", response_model=AdminVoiceListOut)
async def list_voices(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    q: str | None = None,
    user_id: int | None = None,
    provider: str | None = None,
    kind: str | None = None,
    enabled: bool | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminVoiceListOut:
    filters = []
    if user_id is not None:
        filters.append(Voice.user_id == user_id)
    if provider and provider.strip():
        filters.append(Voice.provider == provider.strip().lower())
    if kind and kind.strip():
        filters.append(Voice.kind == kind.strip().lower())
    if enabled is not None:
        filters.append(Voice.enabled.is_(enabled))
    if q and q.strip():
        like = f"%{q.strip()}%"
        filters.append(
            or_(
                Voice.name.ilike(like),
                Voice.provider_voice_id.ilike(like),
                Voice.speech_model.ilike(like),
            )
        )

    count_q = select(func.count()).select_from(Voice)
    list_q = select(Voice).order_by(Voice.sort_order.asc(), Voice.id.asc())
    if filters:
        count_q = count_q.where(*filters)
        list_q = list_q.where(*filters)

    total = int((await db.execute(count_q)).scalar_one())
    rows = (
        await db.execute(list_q.offset((page - 1) * page_size).limit(page_size))
    ).scalars().all()

    user_ids = {v.user_id for v in rows if v.user_id is not None}
    users: dict[int, User] = {}
    if user_ids:
        for u in (
            await db.execute(select(User).where(User.id.in_(user_ids)))
        ).scalars().all():
            users[u.id] = u

    providers = [p for p in SPEECH_PROVIDERS if p != "mock"] + ["mock"]
    env_models = {p: env_speech_model(p) for p in providers}

    items = [
        await _to_out(v, users.get(v.user_id) if v.user_id is not None else None)
        for v in rows
    ]
    return AdminVoiceListOut(
        items=items,
        total=total,
        page=page,
        page_size=page_size,
        speech_providers=providers,
        env_models=env_models,
    )


@router.post("/preview")
async def preview_voice_adhoc(
    body: AdminVoicePreviewIn,
    _: str = Depends(require_admin),
) -> Response:
    """Live synthesize from form fields (not persisted)."""
    if not body.provider or not body.provider_voice_id:
        raise HTTPException(
            status_code=400,
            detail="provider and provider_voice_id are required",
        )
    audio, _ = await _synthesize_preview(
        provider=body.provider,
        provider_voice_id=body.provider_voice_id,
        speech_model=body.speech_model,
        language=body.language,
        text=body.text,
        speed=body.speed,
    )
    return Response(
        content=audio,
        media_type="audio/mpeg",
        headers={"Cache-Control": "no-store"},
    )


@router.get("/{voice_id}", response_model=AdminVoiceOut)
async def get_voice(
    voice_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminVoiceOut:
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    user = await db.get(User, voice.user_id) if voice.user_id is not None else None
    return await _to_out(voice, user)


@router.get("/{voice_id}/preview")
async def get_stored_preview(
    voice_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Return the persisted preview mp3 (404 if none generated yet)."""
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    key = (voice.preview_object_key or "").strip()
    if not key:
        raise HTTPException(status_code=404, detail="Preview audio not generated")
    data = await storage_service.get_bytes(key)
    if not data:
        raise HTTPException(status_code=404, detail="Preview audio missing from storage")
    return Response(
        content=data,
        media_type="audio/mpeg",
        headers={"Cache-Control": "no-store"},
    )


@router.post("/{voice_id}/preview/generate", response_model=AdminVoiceOut)
async def generate_stored_preview(
    voice_id: int,
    body: AdminVoicePreviewGenerateIn | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminVoiceOut:
    """Synthesize sample text with the saved voice binding and persist (overwrite)."""
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    body = body or AdminVoicePreviewGenerateIn()
    text = (body.text or "").strip() or voice.preview_text
    audio, sample = await _synthesize_preview(
        provider=voice.provider or "",
        provider_voice_id=voice.provider_voice_id or "",
        speech_model=voice.speech_model,
        language=voice.language,
        text=text,
        speed=getattr(voice, "speed", None),
    )
    key = _preview_storage_key(voice.id)
    await storage_service.put_bytes(key, audio, "audio/mpeg")
    voice.preview_object_key = key
    voice.preview_text = sample
    voice.preview_generated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(voice)
    user = await db.get(User, voice.user_id) if voice.user_id is not None else None
    return await _to_out(voice, user)


@router.post("", response_model=AdminVoiceOut, status_code=201)
async def create_voice(
    body: AdminVoiceCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminVoiceOut:
    provider = body.provider.strip().lower()
    if provider not in SPEECH_PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Invalid provider: {body.provider}")
    kind = (body.kind or "system").strip().lower()
    if kind not in ("system", "clone"):
        raise HTTPException(status_code=400, detail="kind must be system or clone")

    owner: User | None = None
    owner_id: int | None = None
    if kind == "system":
        owner_id = None
    else:
        if body.user_id is None:
            raise HTTPException(
                status_code=400,
                detail="user_id is required for clone voices",
            )
        owner = await db.get(User, body.user_id)
        if owner is None or owner.deleted_at is not None:
            raise HTTPException(status_code=404, detail="User not found")
        owner_id = owner.id

    mid = (body.speech_model or "").strip() or None
    speed = clamp_speed(body.speed)
    desc = (body.description or "").strip() or None
    if desc and len(desc) > 200:
        desc = desc[:200]
    voice = Voice(
        user_id=owner_id,
        name=body.name.strip(),
        description=desc,
        kind=kind,
        language=(body.language or "zh").strip() or "zh",
        provider=provider,
        provider_voice_id=body.provider_voice_id.strip(),
        speech_model=mid,
        speed=speed,
        speed_tier=tier_for_speed(speed),
        enabled=bool(body.enabled),
        sort_order=int(body.sort_order),
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return await _to_out(voice, owner)


@router.patch("/{voice_id}", response_model=AdminVoiceOut)
async def update_voice(
    voice_id: int,
    body: AdminVoiceUpdate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminVoiceOut:
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Name is required")
        voice.name = name
    if body.description is not None:
        desc = body.description.strip()
        if len(desc) > 200:
            desc = desc[:200]
        voice.description = desc or None
    if body.kind is not None:
        kind = body.kind.strip().lower()
        if kind not in ("system", "clone"):
            raise HTTPException(status_code=400, detail="kind must be system or clone")
        voice.kind = kind
    if body.language is not None:
        voice.language = body.language.strip() or "zh"
    if body.provider is not None:
        provider = body.provider.strip().lower()
        if provider not in SPEECH_PROVIDERS:
            raise HTTPException(status_code=400, detail=f"Invalid provider: {body.provider}")
        voice.provider = provider
    if body.provider_voice_id is not None:
        vid = body.provider_voice_id.strip()
        if not vid:
            raise HTTPException(status_code=400, detail="provider_voice_id is required")
        voice.provider_voice_id = vid
    if body.speech_model is not None:
        mid = body.speech_model.strip()
        voice.speech_model = mid or None
    if body.speed is not None:
        speed = clamp_speed(body.speed)
        voice.speed = speed
        voice.speed_tier = tier_for_speed(speed)
    if body.enabled is not None:
        voice.enabled = bool(body.enabled)
    if body.sort_order is not None:
        voice.sort_order = int(body.sort_order)
    await db.commit()
    await db.refresh(voice)
    user = await db.get(User, voice.user_id) if voice.user_id is not None else None
    return await _to_out(voice, user)


@router.delete("/{voice_id}")
async def delete_voice(
    voice_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    key = (voice.preview_object_key or "").strip()
    if key:
        try:
            await storage_service.delete(key)
        except Exception:
            logger.warning("preview delete failed voice_id=%s key=%s", voice_id, key, exc_info=True)
    await db.delete(voice)
    await db.commit()
    return {"ok": True}
