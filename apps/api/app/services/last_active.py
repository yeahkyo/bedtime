"""Coarse last-seen for admin: touch on account/me (throttled)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User

# Avoid writing on every me poll / tab focus.
TOUCH_INTERVAL = timedelta(minutes=10)


def _as_utc(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


async def touch_user_last_active(db: AsyncSession, user: User) -> bool:
    """Update users.last_active_at if null or older than TOUCH_INTERVAL. Returns whether written."""
    now = datetime.now(timezone.utc)
    prev = user.last_active_at
    if prev is not None and now - _as_utc(prev) < TOUCH_INTERVAL:
        return False
    user.last_active_at = now
    await db.commit()
    return True
