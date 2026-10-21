"""Global system voice catalog + ensure helpers (shared across users)."""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.voice import SYSTEM_VOICE_NAME, Voice
from app.services.provider_settings import env_speech_model, speech_default_voice_id

_BAD_PLACEHOLDER_VOICE_IDS = frozenset({"", "fishaudio-default"})


def voice_accessible_to_user(voice: Voice, user_id: int) -> bool:
    """Global catalog (user_id NULL) or owned by the user."""
    return voice.user_id is None or voice.user_id == user_id


def _pick_enabled_catalog(rows: list[Voice]) -> Voice | None:
    enabled = [r for r in rows if bool(getattr(r, "enabled", True))]
    return enabled[0] if enabled else None


async def _sync_system_row(db: AsyncSession, row: Voice) -> Voice:
    """Light maintenance only — never rewrite a real provider_voice_id."""
    dirty = False
    provider = (row.provider or "").strip().lower()
    current = (row.provider_voice_id or "").strip()
    if current in _BAD_PLACEHOLDER_VOICE_IDS and provider:
        filled = speech_default_voice_id(provider)
        if filled and filled not in _BAD_PLACEHOLDER_VOICE_IDS:
            row.provider_voice_id = filled
            dirty = True
    if row.name == "Gentle System":
        row.name = SYSTEM_VOICE_NAME
        dirty = True
    if not (row.speech_model or "").strip() and provider:
        mid = (env_speech_model(provider) or "").strip()
        if mid:
            row.speech_model = mid
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
    """Return an enabled global system voice from the admin catalog.

    TTS always uses ``Voice.provider`` on the chosen row. There is no global
    speech-provider gate: any enabled catalog voice is eligible.

    ``speech_provider`` is ignored (kept for call-site compat).

    If the catalog is empty, promotes one enabled legacy per-user system row.
    If the catalog has rows but none are enabled, returns 503 (no legacy promote).
    Does not auto-create from env — admin must create/enable voices.
    """
    _ = user
    _ = speech_provider

    catalog = list(
        (
            await db.execute(
                select(Voice)
                .where(Voice.user_id.is_(None), Voice.kind == "system")
                .order_by(Voice.sort_order.asc(), Voice.id.asc())
            )
        ).scalars().all()
    )
    existing = _pick_enabled_catalog(catalog)
    if existing:
        return await _sync_system_row(db, existing)

    # Catalog exists but every global system voice is disabled — do not promote
    # legacy per-user rows (that would undo an intentional admin shutdown).
    if catalog:
        raise HTTPException(
            status_code=503,
            detail="No enabled system voice",
        )

    legacy = (
        await db.execute(
            select(Voice)
            .where(
                Voice.user_id.is_not(None),
                Voice.kind == "system",
                Voice.enabled.is_(True),
            )
            .order_by(Voice.sort_order.asc(), Voice.id.asc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if legacy:
        legacy.user_id = None
        await db.commit()
        await db.refresh(legacy)
        return await _sync_system_row(db, legacy)

    raise HTTPException(
        status_code=503,
        detail="No enabled system voice",
    )
