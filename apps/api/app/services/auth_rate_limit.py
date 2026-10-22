from fastapi import HTTPException, Request, status

from app.core.redis_client import get_redis


async def _incr_window(key: str, limit: int, window_seconds: int) -> None:
    redis = await get_redis()
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, window_seconds)
    if count > limit:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many requests, try again later",
        )


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip() or "unknown"
    if request.client and request.client.host:
        return request.client.host
    return "unknown"


async def rate_limit_auth_ip(request: Request, action: str, *, limit: int = 30, window: int = 60) -> None:
    ip = client_ip(request)
    await _incr_window(f"rl:auth:{action}:ip:{ip}", limit, window)


async def rate_limit_login_phone(phone: str, *, limit: int = 10, window: int = 60) -> None:
    await _incr_window(f"rl:auth:login:phone:{phone}", limit, window)


async def rate_limit_story_ip(request: Request, *, limit: int = 40, window: int = 86400) -> None:
    """Soft daily IP cap for story creates (in addition to per-user monthly quota)."""
    ip = client_ip(request)
    await _incr_window(f"rl:story:ip:{ip}", limit, window)


async def rate_limit_clone_ip(request: Request, *, limit: int = 10, window: int = 86400) -> None:
    ip = client_ip(request)
    await _incr_window(f"rl:clone:ip:{ip}", limit, window)
