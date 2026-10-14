from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.db import get_db
from app.core.security import bearer, get_current_user
from app.models.user import User
from app.schemas.common import QuotaOut, UserOut
from app.services.quota import usage_summary
from app.services.retention import cascade_delete_user, purge_expired_raw_voices, purge_expired_stories


router = APIRouter(prefix="/account", tags=["account"])


@router.get("/me", response_model=UserOut)
async def get_me(user: User = Depends(get_current_user)) -> UserOut:
    return UserOut(
        id=user.id,
        display_name=user.display_name,
        preferred_language=user.preferred_language or "zh",
    )


@router.get("/quota", response_model=QuotaOut)
async def get_quota(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> QuotaOut:
    data = await usage_summary(db, user.id)
    return QuotaOut(**data)


@router.delete("")
async def delete_account(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)) -> dict:
    await cascade_delete_user(db, user.id)
    return {"ok": True, "message": "Account and related data deleted"}


@router.post("/retention/run")
async def run_retention_jobs(
    db: AsyncSession = Depends(get_db),
    x_retention_admin_token: str | None = Header(default=None, alias="X-Retention-Admin-Token"),
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> dict:
    """Global purge. Admin token always accepted when configured; else dev may use auth user."""
    settings = get_settings()
    requested_by: int | None = None
    expected = (settings.retention_admin_token or "").strip()
    token_ok = bool(expected) and x_retention_admin_token == expected

    if token_ok:
        pass
    elif settings.is_dev:
        user = await get_current_user(credentials=credentials, db=db)
        requested_by = user.id
    else:
        raise HTTPException(status_code=403, detail="Retention admin token required")

    raw = await purge_expired_raw_voices(db)
    stories = await purge_expired_stories(db)
    return {"purged_raw_voices": raw, "purged_stories": stories, "requested_by": requested_by}
