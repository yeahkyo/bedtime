from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.voice import Voice
from app.providers.factory import get_clone_provider
from app.schemas.common import VoiceOut, VoiceUpdate
from app.services.quota import check_and_increment
from app.services.retention import raw_voice_purge_at
from app.services.storage import storage_service


router = APIRouter(prefix="/voices", tags=["voices"])


@router.get("", response_model=list[VoiceOut])
async def list_voices(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[VoiceOut]:
    rows = await db.execute(
        select(Voice).where(Voice.user_id == user.id).order_by(Voice.id.asc())
    )
    return list(rows.scalars().all())


@router.patch("/{voice_id}", response_model=VoiceOut)
async def update_voice(
    voice_id: int,
    body: VoiceUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Voice:
    voice = await db.get(Voice, voice_id)
    if voice is None or voice.user_id != user.id:
        raise HTTPException(status_code=404, detail="Voice not found")
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    voice.name = name
    await db.commit()
    await db.refresh(voice)
    return voice


@router.post("/system-default", response_model=VoiceOut)
async def ensure_system_voice(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> Voice:
    settings = get_settings()
    if settings.provider_profile.lower() in ("volc", "doubao", "ark"):
        provider = "volc"
        voice_id = settings.volc_default_speaker
    else:
        provider = "elevenlabs"
        voice_id = settings.elevenlabs_default_voice_id

    existing = (
        await db.execute(select(Voice).where(Voice.user_id == user.id, Voice.kind == "system"))
    ).scalar_one_or_none()
    if existing:
        if existing.provider != provider or existing.provider_voice_id != voice_id:
            existing.provider = provider
            existing.provider_voice_id = voice_id
            await db.commit()
            await db.refresh(existing)
        return existing
    voice = Voice(
        user_id=user.id,
        name="Gentle System",
        kind="system",
        provider=provider,
        provider_voice_id=voice_id,
        language="zh",
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return voice


@router.post("/clone", response_model=VoiceOut)
async def clone_voice(
    consent: bool = Form(...),
    name: str = Form("My voice"),
    language: str = Form("zh"),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Voice:
    if not consent:
        raise HTTPException(status_code=400, detail="Consent required to clone your voice")

    await check_and_increment(db, user.id, "clone")
    audio = await file.read()
    if len(audio) < 1000:
        raise HTTPException(status_code=400, detail="Audio sample too short")

    # Ephemeral store then purge ASAP after clone
    raw_key = storage_service.new_key(f"ephemeral/voices/{user.id}", f"_{file.filename or 'sample.wav'}")
    await storage_service.put_bytes(raw_key, audio, file.content_type or "audio/wav")

    clone = get_clone_provider()
    try:
        provider_voice_id = await clone.clone(name, audio, file.filename or "sample.wav", language)
    except Exception:
        await storage_service.delete(raw_key)
        raise

    # Delete raw immediately after successful clone (retention job is backup)
    await storage_service.delete(raw_key)

    settings = get_settings()
    if settings.provider_profile.lower() in ("volc", "doubao", "ark"):
        provider = "volc"
    elif settings.provider_profile.lower() == "openai":
        provider = "elevenlabs"
    else:
        provider = settings.provider_profile.lower()

    voice = Voice(
        user_id=user.id,
        name=name,
        kind="clone",
        provider=provider,
        provider_voice_id=provider_voice_id,
        language=language,
        consent_at=__import__("datetime").datetime.now(__import__("datetime").timezone.utc),
        raw_object_key=None,
        raw_purge_after=raw_voice_purge_at(),
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return voice


@router.delete("/{voice_id}")
async def delete_voice(
    voice_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> dict:
    voice = await db.get(Voice, voice_id)
    if voice is None or voice.user_id != user.id:
        raise HTTPException(status_code=404, detail="Voice not found")
    if voice.kind == "clone":
        try:
            await get_clone_provider().delete(voice.provider_voice_id)
        except Exception:
            pass
    if voice.raw_object_key:
        await storage_service.delete(voice.raw_object_key)
    await db.delete(voice)
    await db.commit()
    return {"ok": True}
