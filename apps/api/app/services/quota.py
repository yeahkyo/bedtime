from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.redis_client import get_redis
from app.models.usage import UsageLedger

QUOTA_KINDS = ("story", "clone")
_QUOTA_TTL_SECONDS = 60 * 60 * 24 * 40


async def _month_prefix() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m")


def _quota_key(user_id: int, kind: str, month: str) -> str:
    return f"quota:{user_id}:{kind}:{month}"


async def check_and_increment(db: AsyncSession, user_id: int, kind: str, amount: int = 1) -> None:
    settings = get_settings()
    limits = {
        "story": settings.monthly_story_quota,
        "clone": settings.monthly_clone_quota,
    }
    if kind not in limits:
        return

    redis = await get_redis()
    key = _quota_key(user_id, kind, await _month_prefix())
    current = int(await redis.get(key) or 0)
    if current + amount > limits[kind]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Monthly {kind} quota exceeded ({limits[kind]})",
        )
    pipe = redis.pipeline()
    pipe.incrby(key, amount)
    pipe.expire(key, _QUOTA_TTL_SECONDS)
    await pipe.execute()

    db.add(UsageLedger(user_id=user_id, kind=kind, amount=amount))
    await db.commit()


async def usage_summary(db: AsyncSession, user_id: int) -> dict:
    """Redis is source of truth when the key exists (incl. explicit 0 after admin reset)."""
    settings = get_settings()
    month = await _month_prefix()
    redis = await get_redis()

    story_raw = await redis.get(_quota_key(user_id, "story", month))
    clone_raw = await redis.get(_quota_key(user_id, "clone", month))
    story_used = int(story_raw) if story_raw is not None else None
    clone_used = int(clone_raw) if clone_raw is not None else None

    if story_used is None or clone_used is None:
        start = datetime.strptime(month + "-01", "%Y-%m-%d").replace(tzinfo=timezone.utc)
        rows = await db.execute(
            select(UsageLedger.kind, func.coalesce(func.sum(UsageLedger.amount), 0))
            .where(UsageLedger.user_id == user_id, UsageLedger.created_at >= start)
            .group_by(UsageLedger.kind)
        )
        ledger = {kind: int(total) for kind, total in rows.all()}
        if story_used is None:
            story_used = ledger.get("story", 0)
        if clone_used is None:
            clone_used = ledger.get("clone", 0)

    return {
        "month": month,
        "story_used": story_used,
        "story_limit": settings.monthly_story_quota,
        "clone_used": clone_used,
        "clone_limit": settings.monthly_clone_quota,
    }


async def reset_monthly_quota(
    db: AsyncSession,
    user_id: int,
    *,
    kinds: list[str] | None = None,
) -> dict:
    """Reset this month's Redis counters so the user can create again. Ledger kept for audit."""
    selected = [k.strip().lower() for k in (kinds or list(QUOTA_KINDS))]
    invalid = [k for k in selected if k not in QUOTA_KINDS]
    if invalid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid quota kind: {', '.join(invalid)}",
        )
    if not selected:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No quota kinds")

    month = await _month_prefix()
    redis = await get_redis()
    for kind in selected:
        key = _quota_key(user_id, kind, month)
        await redis.set(key, 0, ex=_QUOTA_TTL_SECONDS)

    return await usage_summary(db, user_id)
