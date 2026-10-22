from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.models.user import User


bearer = HTTPBearer(auto_error=False)


def create_access_token(
    subject: str,
    *,
    token_version: int = 0,
    extra: dict[str, Any] | None = None,
) -> str:
    settings = get_settings()
    payload: dict[str, Any] = {
        "sub": subject,
        "aud": "app",
        "ver": int(token_version),
        "exp": datetime.now(timezone.utc)
        + timedelta(minutes=settings.jwt_access_expire_minutes),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def access_expires_in_seconds() -> int:
    return max(1, get_settings().jwt_access_expire_minutes * 60)


def create_admin_token(username: str) -> tuple[str, datetime]:
    settings = get_settings()
    expires = datetime.now(timezone.utc) + timedelta(hours=settings.admin_jwt_expire_hours)
    payload: dict[str, Any] = {
        "sub": username,
        "aud": "admin",
        "typ": "admin",
        "exp": expires,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    return jwt.decode(
        token,
        settings.jwt_secret,
        algorithms=[settings.jwt_algorithm],
        options={"verify_aud": False},
    )


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    settings = get_settings()
    if credentials is None:
        if settings.dev_auth_bypass and settings.is_dev:
            result = await db.execute(select(User).where(User.apple_sub == "dev-parent"))
            user = result.scalar_one_or_none()
            if user is None:
                user = User(
                    apple_sub="dev-parent",
                    display_name="Dev Parent",
                    preferred_language="zh",
                    token_version=0,
                )
                db.add(user)
                await db.commit()
                await db.refresh(user)
            if user.disabled_at is not None:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED, detail="Account disabled"
                )
            return user
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

    try:
        payload = decode_token(credentials.credentials)
        if payload.get("aud") == "admin" or payload.get("typ") == "admin":
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
        sub = payload.get("sub")
        if not sub:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
        ver = payload.get("ver", 0)
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    result = await db.execute(select(User).where(User.apple_sub == sub))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if user.disabled_at is not None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Account disabled")
    if int(user.token_version or 0) != int(ver or 0):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return user


async def require_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> str:
    """Return admin username from Bearer admin JWT."""
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    try:
        payload = decode_token(credentials.credentials)
    except JWTError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc
    if payload.get("aud") != "admin" and payload.get("typ") != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin token required")
    sub = payload.get("sub")
    if not sub:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return str(sub)
