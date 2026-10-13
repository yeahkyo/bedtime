import json
from base64 import urlsafe_b64decode

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.core.security import create_access_token
from app.models.user import User
from app.schemas.common import AppleLoginRequest, DevLoginRequest, TokenResponse


router = APIRouter(prefix="/auth", tags=["auth"])


def _decode_jwt_payload_unverified(token: str) -> dict:
    parts = token.split(".")
    if len(parts) < 2:
        raise HTTPException(status_code=400, detail="Invalid Apple token")
    padded = parts[1] + "=" * (-len(parts[1]) % 4)
    return json.loads(urlsafe_b64decode(padded.encode()))


@router.post("/dev-login", response_model=TokenResponse)
async def dev_login(body: DevLoginRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    settings = get_settings()
    if not (settings.is_dev and settings.dev_auth_bypass):
        raise HTTPException(status_code=403, detail="Dev login disabled")
    result = await db.execute(select(User).where(User.apple_sub == "dev-parent"))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            apple_sub="dev-parent",
            display_name=body.display_name,
            preferred_language=body.preferred_language,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.apple_sub))


@router.post("/apple", response_model=TokenResponse)
async def apple_login(body: AppleLoginRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    settings = get_settings()
    # Baseline: unverified decode is local-dev only. Production needs Apple JWKS verify.
    if not settings.is_dev:
        raise HTTPException(
            status_code=503,
            detail="Apple Sign-In is not configured (JWKS verification required)",
        )
    payload = _decode_jwt_payload_unverified(body.identity_token)
    sub = payload.get("sub")
    if not sub:
        raise HTTPException(status_code=400, detail="Missing sub")
    result = await db.execute(select(User).where(User.apple_sub == sub))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            apple_sub=sub,
            display_name=body.display_name,
            preferred_language=body.preferred_language,
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.apple_sub))
