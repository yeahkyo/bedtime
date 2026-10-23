from datetime import datetime, timezone
import logging

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import Response
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.voice import Voice
from app.providers.factory import get_clone_provider
from app.schemas.common import VoiceOut, VoiceUpdate
from app.services.auth_rate_limit import rate_limit_clone_ip
from app.services.provider_settings import (
    first_configured_speech_provider,
    resolve_speech_model,
)
from app.services.quota import check_and_increment
from app.services.retention import raw_voice_purge_at
from app.services.storage import storage_service
from app.services.system_voice import ensure_system_voice, voice_accessible_to_user


logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voices", tags=["voices"])


async def _to_voice_out(voice: Voice) -> VoiceOut:
    preview_url: str | None = None
    key = (getattr(voice, "preview_object_key", None) or "").strip()
    if key:
        try:
            preview_url = await storage_service.presigned_url(key)
        except Exception:
            logger.warning("preview url failed voice_id=%s key=%s", voice.id, key, exc_info=True)
            preview_url = None
    desc = (getattr(voice, "description", None) or "").strip() or None
    return VoiceOut(
        id=voice.id,
        name=voice.name,
        kind=voice.kind,
        language=voice.language or "zh",
        provider=voice.provider or "fishaudio",
        provider_voice_id=voice.provider_voice_id or "",
        speech_model=voice.speech_model,
        speed_tier=getattr(voice, "speed_tier", None) or "medium",
        speed=float(getattr(voice, "speed", None) or 1.0),
        enabled=bool(getattr(voice, "enabled", True)),
        description=desc,
        sort_order=int(getattr(voice, "sort_order", 0) or 0),
        preview_audio_url=preview_url,
    )


def _filter_visible_voices(rows: list[Voice]) -> list[Voice]:
    # Hide legacy per-user system rows once a global catalog voice exists for that provider.
    global_providers = {
        (v.provider or "").strip().lower()
        for v in rows
        if v.user_id is None and v.kind == "system"
    }
    return [
        v
        for v in rows
        if not (
            v.user_id is not None
            and v.kind == "system"
            and (v.provider or "").strip().lower() in global_providers
        )
    ]


@router.get("", response_model=list[VoiceOut])
async def list_voices(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[VoiceOut]:
    rows = (
        await db.execute(
            select(Voice)
            .where(
                or_(Voice.user_id.is_(None), Voice.user_id == user.id),
                Voice.enabled.is_(True),
            )
            .order_by(Voice.sort_order.asc(), Voice.id.asc())
        )
    ).scalars().all()
    visible = _filter_visible_voices(list(rows))
    if not get_settings().feature_voice_clone:
        visible = [v for v in visible if v.kind != "clone"]
    return [await _to_voice_out(v) for v in visible]


@router.get("/{voice_id}/preview")
async def get_voice_preview(
    voice_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Stream persisted preview mp3 for an accessible, enabled voice."""
    voice = await db.get(Voice, voice_id)
    if (
        voice is None
        or not voice_accessible_to_user(voice, user.id)
        or not bool(getattr(voice, "enabled", True))
    ):
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


@router.patch("/{voice_id}", response_model=VoiceOut)
async def update_voice(
    voice_id: int,
    body: VoiceUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VoiceOut:
    voice = await db.get(Voice, voice_id)
    # Users may only rename their own clones — global catalog is admin-only.
    # Provider / model / provider_voice_id are admin-managed (ignore client spoofing).
    if voice is None or voice.user_id != user.id:
        raise HTTPException(status_code=404, detail="Voice not found")
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    voice.name = name
    await db.commit()
    await db.refresh(voice)
    return await _to_voice_out(voice)


@router.post("/system-default", response_model=VoiceOut)
async def ensure_system_voice_route(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> VoiceOut:
    voice = await ensure_system_voice(db, user)
    return await _to_voice_out(voice)


@router.post("/clone", response_model=VoiceOut)
async def clone_voice(
    request: Request,
    consent: bool = Form(...),
    name: str = Form("My voice"),
    language: str = Form("zh"),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> VoiceOut:
    if not get_settings().feature_voice_clone:
        raise HTTPException(status_code=403, detail="Voice clone is not available")
    if not consent:
        raise HTTPException(status_code=400, detail="Consent required to clone your voice")

    await rate_limit_clone_ip(request)
    await check_and_increment(db, user.id, "clone")
    audio = await file.read()
    if len(audio) < 1000:
        raise HTTPException(status_code=400, detail="Audio sample too short")

    # Clone backend follows an enabled catalog voice when present; else first configured key.
    catalog = (
        await db.execute(
            select(Voice)
            .where(
                Voice.user_id.is_(None),
                Voice.kind == "system",
                Voice.enabled.is_(True),
            )
            .order_by(Voice.sort_order.asc(), Voice.id.asc())
            .limit(1)
        )
    ).scalar_one_or_none()
    speech_provider = (
        (catalog.provider if catalog else None) or first_configured_speech_provider()
    ).strip().lower()
    speech_model = (await resolve_speech_model(speech_provider) or "").strip() or None

    # Ephemeral store then purge ASAP after clone
    raw_key = storage_service.new_key(f"ephemeral/voices/{user.id}", f"_{file.filename or 'sample.wav'}")
    await storage_service.put_bytes(raw_key, audio, file.content_type or "audio/wav")

    clone = get_clone_provider(speech_provider)
    try:
        provider_voice_id = await clone.clone(name, audio, file.filename or "sample.wav", language)
    except Exception:
        await storage_service.delete(raw_key)
        raise

    # Delete raw immediately after successful clone (retention job is backup)
    await storage_service.delete(raw_key)

    voice = Voice(
        user_id=user.id,
        name=name,
        kind="clone",
        provider=speech_provider,
        provider_voice_id=provider_voice_id,
        speech_model=speech_model,
        speed_tier="medium",
        speed=1.0,
        language=language,
        consent_at=datetime.now(timezone.utc),
        raw_object_key=None,
        raw_purge_after=raw_voice_purge_at(),
        enabled=True,
        sort_order=1000,
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return await _to_voice_out(voice)


@router.delete("/{voice_id}")
async def delete_voice(
    voice_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> dict:
    voice = await db.get(Voice, voice_id)
    # Global catalog voices cannot be deleted by end users.
    if voice is None or voice.user_id != user.id:
        raise HTTPException(status_code=404, detail="Voice not found")
    if voice.kind == "clone":
        try:
            await get_clone_provider(voice.provider).delete(voice.provider_voice_id)
        except Exception:
            pass
    if voice.raw_object_key:
        await storage_service.delete(voice.raw_object_key)
    if voice.preview_object_key:
        try:
            await storage_service.delete(voice.preview_object_key)
        except Exception:
            pass
    await db.delete(voice)
    await db.commit()
    return {"ok": True}
