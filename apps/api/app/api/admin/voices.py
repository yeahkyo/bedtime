"""Admin CRUD for voice catalog (global system presets + per-user clones)."""

from __future__ import annotations

import logging

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
from app.services.voice_settings import (
    SPEED_TIERS,
    normalize_speed_tier,
    resolve_voice_settings,
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
    kind: str
    language: str
    provider: str
    provider_voice_id: str
    speech_model: str | None = None
    speed_tier: str = "medium"
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
    kind: str | None = None
    language: str | None = Field(default=None, max_length=8)
    provider: str | None = None
    provider_voice_id: str | None = Field(default=None, max_length=128)
    speech_model: str | None = None  # empty string clears override
    speed_tier: str | None = None


class AdminVoiceCreate(BaseModel):
    """system → global catalog (user_id ignored). clone → requires user_id."""

    user_id: int | None = None
    name: str = Field(min_length=1, max_length=64)
    kind: str = "system"
    language: str = "zh"
    provider: str
    provider_voice_id: str = Field(min_length=1, max_length=128)
    speech_model: str | None = None
    speed_tier: str = "medium"


class AdminVoicePreviewIn(BaseModel):
    """Ad-hoc preview (unsaved form) or optional text override for saved voice."""

    provider: str | None = None
    provider_voice_id: str | None = None
    speech_model: str | None = None
    language: str | None = None
    speed_tier: str | None = None
    text: str | None = Field(default=None, max_length=_PREVIEW_TEXT_MAX)


def _default_preview_text(language: str | None) -> str:
    lang = (language or "zh").strip().lower()
    if lang.startswith("en"):
        return _PREVIEW_TEXT_EN
    return _PREVIEW_TEXT_ZH


async def _synthesize_preview(
    *,
    provider: str,
    provider_voice_id: str,
    speech_model: str | None,
    language: str | None,
    text: str | None,
    speed_tier: str | None = None,
) -> bytes:
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
    vs = resolve_voice_settings(normalize_speed_tier(speed_tier), "gentle", False)
    tts = get_tts_provider(name)
    try:
        audio, _ = await synthesize_with_prosody(
            tts,
            sample,
            voice_id,
            vs,
            speech_provider=name,
            model=model or None,
        )
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
    return audio


def _to_out(voice: Voice, user: User | None = None) -> AdminVoiceOut:
    return AdminVoiceOut(
        id=voice.id,
        user_id=voice.user_id,
        user_display_name=user.display_name if user else None,
        name=voice.name,
        kind=voice.kind,
        language=voice.language or "zh",
        provider=voice.provider or "",
        provider_voice_id=voice.provider_voice_id or "",
        speech_model=voice.speech_model,
        speed_tier=normalize_speed_tier(getattr(voice, "speed_tier", None)),
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
    list_q = select(Voice).order_by(Voice.id.desc())
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

    return AdminVoiceListOut(
        items=[
            _to_out(v, users.get(v.user_id) if v.user_id is not None else None)
            for v in rows
        ],
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
    """Synthesize a short sample from form fields (no save required)."""
    if not body.provider or not body.provider_voice_id:
        raise HTTPException(
            status_code=400,
            detail="provider and provider_voice_id are required",
        )
    audio = await _synthesize_preview(
        provider=body.provider,
        provider_voice_id=body.provider_voice_id,
        speech_model=body.speech_model,
        language=body.language,
        text=body.text,
        speed_tier=body.speed_tier,
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
    return _to_out(voice, user)


@router.post("/{voice_id}/preview")
async def preview_voice(
    voice_id: int,
    body: AdminVoicePreviewIn | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Synthesize a short sample with the saved voice binding."""
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    body = body or AdminVoicePreviewIn()
    # Optional overrides let dialog preview edits before save.
    provider = (body.provider or voice.provider or "").strip().lower()
    provider_voice_id = (body.provider_voice_id or voice.provider_voice_id or "").strip()
    speech_model = (
        body.speech_model
        if body.speech_model is not None
        else voice.speech_model
    )
    language = body.language or voice.language
    speed_tier = (
        body.speed_tier
        if body.speed_tier is not None
        else getattr(voice, "speed_tier", None)
    )
    audio = await _synthesize_preview(
        provider=provider,
        provider_voice_id=provider_voice_id,
        speech_model=speech_model,
        language=language,
        text=body.text,
        speed_tier=speed_tier,
    )
    return Response(
        content=audio,
        media_type="audio/mpeg",
        headers={"Cache-Control": "no-store"},
    )


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
        # Shared catalog — ignore any client-provided user_id.
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
    raw_tier = (body.speed_tier or "").strip().lower()
    if raw_tier and raw_tier not in SPEED_TIERS:
        raise HTTPException(status_code=400, detail="speed_tier must be slow|medium|fast")
    tier = normalize_speed_tier(raw_tier or None)
    voice = Voice(
        user_id=owner_id,
        name=body.name.strip(),
        kind=kind,
        language=(body.language or "zh").strip() or "zh",
        provider=provider,
        provider_voice_id=body.provider_voice_id.strip(),
        speech_model=mid,
        speed_tier=tier,
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return _to_out(voice, owner)


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
    if body.speed_tier is not None:
        tier = body.speed_tier.strip().lower()
        if tier not in SPEED_TIERS:
            raise HTTPException(status_code=400, detail="speed_tier must be slow|medium|fast")
        voice.speed_tier = tier
    await db.commit()
    await db.refresh(voice)
    user = await db.get(User, voice.user_id) if voice.user_id is not None else None
    return _to_out(voice, user)


@router.delete("/{voice_id}")
async def delete_voice(
    voice_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    voice = await db.get(Voice, voice_id)
    if voice is None:
        raise HTTPException(status_code=404, detail="Voice not found")
    await db.delete(voice)
    await db.commit()
    return {"ok": True}
