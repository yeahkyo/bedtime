"""Global system voice catalog + ensure helpers (shared across users)."""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.voice import SYSTEM_VOICE_NAME, Voice
from app.services.provider_settings import (
    env_speech_model,
    resolve_speech_model,
    resolve_speech_provider_name,
    speech_default_voice_id,
)

_BAD_PLACEHOLDER_VOICE_IDS = frozenset({"", "fishaudio-default"})


def voice_accessible_to_user(voice: Voice, user_id: int) -> bool:
    """Global catalog (user_id NULL) or owned by the user."""
    return voice.user_id is None or voice.user_id == user_id


def _require_configured_voice_id(provider: str, voice_id: str) -> str:
    cleaned = (voice_id or "").strip()
    if cleaned and cleaned not in _BAD_PLACEHOLDER_VOICE_IDS:
        return cleaned
    if provider == "fishaudio":
        raise HTTPException(
            status_code=503,
            detail="Fish Audio default voice id is not configured",
        )
    if provider in ("aliyun", "dashscope", "cosyvoice"):
        raise HTTPException(
            status_code=503,
            detail="Aliyun CosyVoice default voice is not configured (ALIYUN_TTS_DEFAULT_VOICE)",
        )
    raise HTTPException(
        status_code=503,
        detail="Speech provider default voice is not configured",
    )


def _pick_catalog_voice(rows: list[Voice], *, configured_id: str) -> Voice | None:
    """Prefer env default voice id; otherwise oldest row. Allows many voices per provider."""
    if not rows:
        return None
    want = (configured_id or "").strip()
    if want:
        for row in rows:
            if (row.provider_voice_id or "").strip() == want:
                return row
    return rows[0]


async def _sync_system_row(
    db: AsyncSession,
    row: Voice,
    *,
    configured_id: str,
    default_model: str | None,
    provider: str,
) -> Voice:
    """Light maintenance only — never rewrite a real provider_voice_id (multi-voice catalog)."""
    dirty = False
    current = (row.provider_voice_id or "").strip()
    if current in _BAD_PLACEHOLDER_VOICE_IDS:
        row.provider_voice_id = _require_configured_voice_id(provider, configured_id)
        dirty = True
    if row.name == "Gentle System":
        row.name = SYSTEM_VOICE_NAME
        dirty = True
    if not (row.speech_model or "").strip() and default_model:
        row.speech_model = default_model
        dirty = True
    if dirty:
        await db.commit()
        await db.refresh(row)
    return row


async def ensure_system_voice(
    db: AsyncSession,
    user: User,
    speech_provider: str | None = None,
) -> Voice:
    """Return a shared system voice for the active speech provider.

    Catalog may contain multiple global ``system`` rows per provider (different
    voice ids / models). Picks the env default voice id when present, else the
    oldest row. Creates one global row only when the catalog is empty.
    """
    _ = user
    provider = (speech_provider or await resolve_speech_provider_name()).strip().lower()
    configured_id = speech_default_voice_id(provider)
    default_model = (
        await resolve_speech_model(provider)
    ) or env_speech_model(provider) or None

    catalog = (
        await db.execute(
            select(Voice)
            .where(
                Voice.user_id.is_(None),
                Voice.kind == "system",
                Voice.provider == provider,
            )
            .order_by(Voice.id.asc())
        )
    ).scalars().all()
    existing = _pick_catalog_voice(list(catalog), configured_id=configured_id)
    if existing:
        return await _sync_system_row(
            db,
            existing,
            configured_id=configured_id,
            default_model=default_model,
            provider=provider,
        )

    # Promote one legacy per-user system row so older installs become shared.
    legacy = (
        await db.execute(
            select(Voice)
            .where(
                Voice.user_id.is_not(None),
                Voice.kind == "system",
                Voice.provider == provider,
            )
            .order_by(Voice.id.asc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if legacy:
        legacy.user_id = None
        await db.commit()
        await db.refresh(legacy)
        return await _sync_system_row(
            db,
            legacy,
            configured_id=configured_id,
            default_model=default_model,
            provider=provider,
        )

    voice_id = _require_configured_voice_id(provider, configured_id)
    voice = Voice(
        user_id=None,
        name=SYSTEM_VOICE_NAME,
        kind="system",
        provider=provider,
        provider_voice_id=voice_id,
        speech_model=default_model,
        speed_tier="medium",
        language="zh",
    )
    db.add(voice)
    await db.commit()
    await db.refresh(voice)
    return voice
