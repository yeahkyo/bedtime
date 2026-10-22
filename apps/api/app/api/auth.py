import json
from base64 import urlsafe_b64decode
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.core.security import access_expires_in_seconds, create_access_token
from app.models.invite import InviteCode
from app.models.user import User
from app.schemas.common import (
    AppleLoginRequest,
    DevLoginRequest,
    LoginRequest,
    LogoutRequest,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
)
from app.services.auth_rate_limit import rate_limit_auth_ip, rate_limit_login_phone
from app.services.passwords import hash_password, verify_password
from app.services.phone import apple_sub_for_phone, normalize_phone
from app.services.refresh_tokens import (
    hash_refresh_token,
    issue_refresh_token,
    revoke_refresh_by_hash,
    rotate_refresh_token,
)


router = APIRouter(prefix="/auth", tags=["auth"])


def _decode_jwt_payload_unverified(token: str) -> dict:
    parts = token.split(".")
    if len(parts) < 2:
        raise HTTPException(status_code=400, detail="Invalid Apple token")
    padded = parts[1] + "=" * (-len(parts[1]) % 4)
    return json.loads(urlsafe_b64decode(padded.encode()))


async def _token_pair(db: AsyncSession, user: User, *, user_agent: str | None = None) -> TokenResponse:
    refresh = await issue_refresh_token(db, user, user_agent=user_agent)
    await db.commit()
    return TokenResponse(
        access_token=create_access_token(
            user.apple_sub, token_version=int(user.token_version or 0)
        ),
        refresh_token=refresh,
        expires_in=access_expires_in_seconds(),
    )


def _invite_usable(invite: InviteCode, now: datetime) -> str | None:
    """Return error detail if unusable, else None."""
    if invite.revoked_at is not None:
        return "Invite code is not valid"
    if invite.used_at is not None:
        return "Invite code is not valid"
    if invite.expires_at is not None:
        exp = invite.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if exp <= now:
            return "Invite code is not valid"
    return None


@router.post("/register", response_model=TokenResponse)
async def register(
    body: RegisterRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    await rate_limit_auth_ip(request, "register", limit=20, window=60)
    phone = normalize_phone(body.phone)
    code = body.invite_code.strip().upper()
    now = datetime.now(timezone.utc)

    # Lock invite row so concurrent registers cannot both consume the same code.
    invite = (
        await db.execute(
            select(InviteCode).where(InviteCode.code == code).with_for_update()
        )
    ).scalar_one_or_none()
    if invite is None:
        raise HTTPException(status_code=400, detail="Invite code is not valid")
    err = _invite_usable(invite, now)
    if err:
        raise HTTPException(status_code=400, detail=err)

    existing = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status_code=400, detail="Phone already registered")

    user = User(
        apple_sub=apple_sub_for_phone(phone),
        phone=phone,
        password_hash=hash_password(body.password),
        display_name=body.display_name or f"用户{phone[-4:]}",
        preferred_language=body.preferred_language or "zh",
        token_version=0,
    )
    db.add(user)
    await db.flush()
    invite.used_at = now
    invite.used_by_user_id = user.id
    return await _token_pair(db, user, user_agent=request.headers.get("user-agent"))


@router.post("/login", response_model=TokenResponse)
async def login(
    body: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    await rate_limit_auth_ip(request, "login", limit=30, window=60)
    try:
        phone = normalize_phone(body.phone)
    except HTTPException:
        raise HTTPException(status_code=401, detail="手机号或密码错误") from None
    await rate_limit_login_phone(phone, limit=10, window=60)

    user = (await db.execute(select(User).where(User.phone == phone))).scalar_one_or_none()
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="手机号或密码错误")
    if user.disabled_at is not None:
        raise HTTPException(status_code=401, detail="Account disabled")
    if user.deleted_at is not None:
        raise HTTPException(status_code=401, detail="手机号或密码错误")
    return await _token_pair(db, user, user_agent=request.headers.get("user-agent"))


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    body: RefreshRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    await rate_limit_auth_ip(request, "refresh", limit=60, window=60)
    try:
        user, new_raw = await rotate_refresh_token(
            db, body.refresh_token, user_agent=request.headers.get("user-agent")
        )
    except ValueError as exc:
        # Persist reuse/disabled mass-revoke (and expired-row marks) before 401.
        await db.commit()
        code = str(exc)
        if code == "disabled":
            raise HTTPException(status_code=401, detail="Account disabled") from exc
        raise HTTPException(status_code=401, detail="Invalid refresh token") from exc
    await db.commit()
    return TokenResponse(
        access_token=create_access_token(
            user.apple_sub, token_version=int(user.token_version or 0)
        ),
        refresh_token=new_raw,
        expires_in=access_expires_in_seconds(),
    )


@router.post("/logout")
async def logout(body: LogoutRequest, db: AsyncSession = Depends(get_db)) -> dict:
    await revoke_refresh_by_hash(db, hash_refresh_token(body.refresh_token))
    await db.commit()
    return {"ok": True}


@router.post("/dev-login", response_model=TokenResponse)
async def dev_login(
    body: DevLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    """Explicit token mint for local App testing. Requires ENV=dev only."""
    settings = get_settings()
    if not settings.is_dev:
        raise HTTPException(status_code=403, detail="Dev login disabled")
    result = await db.execute(select(User).where(User.apple_sub == "dev-parent"))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            apple_sub="dev-parent",
            display_name=body.display_name,
            preferred_language=body.preferred_language,
            token_version=0,
        )
        db.add(user)
        await db.flush()
    if user.disabled_at is not None:
        raise HTTPException(status_code=401, detail="Account disabled")
    return await _token_pair(db, user, user_agent=request.headers.get("user-agent"))


@router.post("/apple", response_model=TokenResponse)
async def apple_login(
    body: AppleLoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
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
            token_version=0,
        )
        db.add(user)
        await db.flush()
    if user.disabled_at is not None:
        raise HTTPException(status_code=401, detail="Account disabled")
    return await _token_pair(db, user, user_agent=request.headers.get("user-agent"))
