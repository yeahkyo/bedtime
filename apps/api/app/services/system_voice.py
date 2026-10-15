"""Ensure per-user system voices keyed by speech provider."""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.voice import SYSTEM_VOICE_NAME, Voice
from app.services.provider_settings import (
    resolve_speech_provider_name,
    speech_default_voice_id,
)

_BAD_PLACEHOLDER_VOICE_IDS = frozenset({"", "fishaudio-default"})


def _require_configured_voice_id(provider: str, voice_id: str) -> str:
    cleaned = (voice_id or "").strip()
    if cleaned and cleaned not in _BAD_PLACEHOLDER_VOICE_IDS:
        return cleaned
    if provider == "fishaudio":
        raise HTTPException(
            status_code=503,
            detail="Fish Audio default voice id is not configured",
        )
    raise HTTPException(
        status_code=503,
        detail="Speech provider default voice is not configured",
    )


async def ensure_system_voice(
    db: AsyncSession,
    user: User,
    speech_provider: str | None = None,
) -> Voice:
    provider = (speech_provider or await resolve_speech_provider_name()).strip().lower()
    configured_id = speech_default_voice_id(provider)

    existing = (
        await db.execute(
            select(Voice).where(
                Voice.user_id == user.id,
                Voice.kind == "system",
                Voice.provider == provider,
            )
        )
    ).scalar_one_or_none()
    if existing:
        dirty = False
        current = (existing.provider_voice_id or "").strip()
        if configured_id and current != configured_id:
            existing.provider_voice_id = configured_id
            dirty = True
        elif current in _BAD_PLACEHOLDER_VOICE_IDS:
            # Existing row is unusable; require a real env voice id.
            existing.provider_voice_id = _require_configured_voice_id(provider, configured_id)
            dirty = True
        if existing.name == "Gentle System":
            existing.name = SYSTEM_VOICE_NAME
            dirty = True
        if dirty:
            await db.commit()
            await db.refresh(existing)
        return existing

    # Legacy: single system row without matching provider — migrate in place if alone.
    legacy = (
        await db.execute(
            select(Voice).where(Voice.user_id == user.id, Voice.kind == "system")
        )
    ).scalars().all()
    voice_id = _require_configured_voice_id(provider, configured_id)
    if len(legacy) == 1 and legacy[0].provider != provider:
        row = legacy[0]
        row.provider = provider
        row.provider_voice_id = voice_id
        if row.name == "Gentle System":
            row.name = SYSTEM_VOICE_NAME
        await db.commit()
        await db.refresh(row)
        return row

    voice = Voice(
        user_id=user.id,
        name=SYSTEM_VOICE_NAME,
        kind="system",
        provider=provider,
        provider_voice_id=voice_id,
        language="zh",
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return voice
