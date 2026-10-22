import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.refresh_token import RefreshToken
from app.models.user import User


def hash_refresh_token(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def new_refresh_token_value() -> str:
    return secrets.token_urlsafe(32)


async def issue_refresh_token(
    db: AsyncSession,
    user: User,
    *,
    user_agent: str | None = None,
) -> str:
    settings = get_settings()
    raw = new_refresh_token_value()
    row = RefreshToken(
        user_id=user.id,
        token_hash=hash_refresh_token(raw),
        expires_at=datetime.now(timezone.utc)
        + timedelta(days=settings.jwt_refresh_expire_days),
        user_agent=(user_agent or "")[:256] or None,
    )
    db.add(row)
    await db.flush()
    return raw


async def revoke_refresh_by_hash(db: AsyncSession, token_hash: str) -> bool:
    row = (
        await db.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
    ).scalar_one_or_none()
    if row is None:
        return False
    if row.revoked_at is None:
        row.revoked_at = datetime.now(timezone.utc)
    return True


async def revoke_all_refresh(db: AsyncSession, user_id: int) -> int:
    now = datetime.now(timezone.utc)
    result = await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    return int(result.rowcount or 0)


async def bump_token_version_and_revoke(db: AsyncSession, user: User) -> None:
    user.token_version = int(user.token_version or 0) + 1
    await revoke_all_refresh(db, user.id)


async def rotate_refresh_token(
    db: AsyncSession,
    raw_refresh: str,
    *,
    user_agent: str | None = None,
) -> tuple[User, str]:
    """Validate refresh, rotate, return (user, new_raw_refresh).

    Raises ValueError with stable codes: invalid | reuse | disabled
    """
    token_hash = hash_refresh_token(raw_refresh)
    # Lock the row so concurrent refreshes cannot both mint a successor.
    row = (
        await db.execute(
            select(RefreshToken)
            .where(RefreshToken.token_hash == token_hash)
            .with_for_update()
        )
    ).scalar_one_or_none()
    if row is None:
        raise ValueError("invalid")

    now = datetime.now(timezone.utc)
    if row.revoked_at is not None:
        await revoke_all_refresh(db, row.user_id)
        raise ValueError("reuse")

    exp = row.expires_at
    if exp.tzinfo is None:
        exp = exp.replace(tzinfo=timezone.utc)
    if exp <= now:
        row.revoked_at = now
        raise ValueError("invalid")

    user = await db.get(User, row.user_id)
    if user is None or user.deleted_at is not None:
        row.revoked_at = now
        raise ValueError("invalid")
    if user.disabled_at is not None:
        await revoke_all_refresh(db, user.id)
        raise ValueError("disabled")

    new_raw = new_refresh_token_value()
    new_row = RefreshToken(
        user_id=user.id,
        token_hash=hash_refresh_token(new_raw),
        expires_at=now + timedelta(days=get_settings().jwt_refresh_expire_days),
        user_agent=(user_agent or "")[:256] or None,
    )
    db.add(new_row)
    await db.flush()
    row.revoked_at = now
    row.replaced_by_id = new_row.id
    return user, new_raw
