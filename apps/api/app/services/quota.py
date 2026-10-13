from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.redis_client import get_redis
from app.models.usage import UsageLedger


async def _month_prefix() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m")


async def check_and_increment(db: AsyncSession, user_id: int, kind: str, amount: int = 1) -> None:
    settings = get_settings()
    limits = {
        "story": settings.monthly_story_quota,
        "clone": settings.monthly_clone_quota,
    }
    if kind not in limits:
        return

    redis = await get_redis()
    key = f"quota:{user_id}:{kind}:{await _month_prefix()}"
    current = int(await redis.get(key) or 0)
    if current + amount > limits[kind]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Monthly {kind} quota exceeded ({limits[kind]})",
        )
    pipe = redis.pipeline()
    pipe.incrby(key, amount)
    pipe.expire(key, 60 * 60 * 24 * 40)
    await pipe.execute()

    db.add(UsageLedger(user_id=user_id, kind=kind, amount=amount))
    await db.commit()


async def usage_summary(db: AsyncSession, user_id: int) -> dict:
    settings = get_settings()
    month = await _month_prefix()
    redis = await get_redis()
    story_used = int(await redis.get(f"quota:{user_id}:story:{month}") or 0)
    clone_used = int(await redis.get(f"quota:{user_id}:clone:{month}") or 0)

    if story_used == 0 or clone_used == 0:
        start = datetime.strptime(month + "-01", "%Y-%m-%d").replace(tzinfo=timezone.utc)
        rows = await db.execute(
            select(UsageLedger.kind, func.coalesce(func.sum(UsageLedger.amount), 0))
            .where(UsageLedger.user_id == user_id, UsageLedger.created_at >= start)
            .group_by(UsageLedger.kind)
        )
        for kind, total in rows.all():
            if kind == "story" and story_used == 0:
                story_used = int(total)
            if kind == "clone" and clone_used == 0:
                clone_used = int(total)

    return {
        "month": month,
        "story_used": story_used,
        "story_limit": settings.monthly_story_quota,
        "clone_used": clone_used,
        "clone_limit": settings.monthly_clone_quota,
    }
