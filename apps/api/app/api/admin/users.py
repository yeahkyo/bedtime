from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.security import require_admin
from app.models.child import Child
from app.models.story import Story
from app.models.user import User
from app.models.voice import Voice
from app.services.quota import QUOTA_KINDS, reset_monthly_quota, usage_summary

router = APIRouter(prefix="/users", tags=["admin-users"])


class AdminUserListItem(BaseModel):
    id: int
    display_name: str | None
    preferred_language: str
    apple_sub: str
    created_at: str | None
    story_used: int = 0
    story_limit: int = 0
    clone_used: int = 0
    clone_limit: int = 0
    children_count: int = 0
    stories_count: int = 0


class AdminUserListOut(BaseModel):
    items: list[AdminUserListItem]
    total: int
    page: int
    page_size: int


class AdminChildBrief(BaseModel):
    id: int
    nickname: str
    age_band: str
    birth_date: str | None = None
    gender: str = "unspecified"
    intro: str | None = None


class AdminVoiceBrief(BaseModel):
    id: int
    name: str
    kind: str
    provider: str
    provider_voice_id: str = ""
    speech_model: str | None = None


class AdminUserDetailOut(BaseModel):
    id: int
    display_name: str | None
    preferred_language: str
    apple_sub: str
    created_at: str | None
    deleted_at: str | None
    story_retention_months: int
    story_used: int
    story_limit: int
    clone_used: int
    clone_limit: int
    quota_month: str | None = None
    children: list[AdminChildBrief]
    voices: list[AdminVoiceBrief]
    stories_count: int


class AdminQuotaResetIn(BaseModel):
    """Reset current-month Redis counters. kinds: story | clone | omit for both."""

    kinds: list[str] | None = None


class AdminQuotaOut(BaseModel):
    month: str
    story_used: int
    story_limit: int
    clone_used: int
    clone_limit: int


@router.get("", response_model=AdminUserListOut)
async def list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    q: str | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminUserListOut:
    filters = [User.deleted_at.is_(None)]
    if q and q.strip():
        like = f"%{q.strip()}%"
        filters.append(or_(User.display_name.ilike(like), User.apple_sub.ilike(like)))
    total = int(
        (
            await db.execute(select(func.count()).select_from(User).where(*filters))
        ).scalar_one()
    )
    rows = (
        await db.execute(
            select(User)
            .where(*filters)
            .order_by(User.id.desc())
            .offset((page - 1) * page_size)
            .limit(page_size)
        )
    ).scalars().all()

    items: list[AdminUserListItem] = []
    for user in rows:
        usage = await usage_summary(db, user.id)
        children_count = int(
            (
                await db.execute(
                    select(func.count()).select_from(Child).where(Child.user_id == user.id)
                )
            ).scalar_one()
        )
        stories_count = int(
            (
                await db.execute(
                    select(func.count()).select_from(Story).where(Story.user_id == user.id)
                )
            ).scalar_one()
        )
        items.append(
            AdminUserListItem(
                id=user.id,
                display_name=user.display_name,
                preferred_language=user.preferred_language,
                apple_sub=user.apple_sub,
                created_at=user.created_at.isoformat() if user.created_at else None,
                story_used=usage["story_used"],
                story_limit=usage["story_limit"],
                clone_used=usage["clone_used"],
                clone_limit=usage["clone_limit"],
                children_count=children_count,
                stories_count=stories_count,
            )
        )
    return AdminUserListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/{user_id}", response_model=AdminUserDetailOut)
async def get_user(
    user_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminUserDetailOut:
    user = (
        await db.execute(
            select(User)
            .where(User.id == user_id)
            .options(selectinload(User.children), selectinload(User.voices))
        )
    ).scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    usage = await usage_summary(db, user.id)
    stories_count = int(
        (
            await db.execute(
                select(func.count()).select_from(Story).where(Story.user_id == user.id)
            )
        ).scalar_one()
    )
    return AdminUserDetailOut(
        id=user.id,
        display_name=user.display_name,
        preferred_language=user.preferred_language,
        apple_sub=user.apple_sub,
        created_at=user.created_at.isoformat() if user.created_at else None,
        deleted_at=user.deleted_at.isoformat() if user.deleted_at else None,
        story_retention_months=user.story_retention_months,
        story_used=usage["story_used"],
        story_limit=usage["story_limit"],
        clone_used=usage["clone_used"],
        clone_limit=usage["clone_limit"],
        quota_month=usage.get("month"),
        children=[
            AdminChildBrief(
                id=c.id,
                nickname=c.nickname,
                age_band=c.age_band,
                birth_date=c.birth_date.isoformat() if c.birth_date else None,
                gender=c.gender or "unspecified",
                intro=c.intro,
            )
            for c in user.children
        ],
        voices=[
            AdminVoiceBrief(
                id=v.id,
                name=v.name,
                kind=v.kind,
                provider=v.provider or "",
                provider_voice_id=v.provider_voice_id or "",
                speech_model=v.speech_model,
            )
            for v in user.voices
        ],
        stories_count=stories_count,
    )


@router.post("/{user_id}/quota/reset", response_model=AdminQuotaOut)
async def reset_user_quota(
    user_id: int,
    body: AdminQuotaResetIn | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminQuotaOut:
    """Clear this month's story/clone Redis counters so the account can create again."""
    user = await db.get(User, user_id)
    if user is None or user.deleted_at is not None:
        raise HTTPException(status_code=404, detail="User not found")
    kinds = body.kinds if body is not None else None
    if kinds is not None and len(kinds) == 0:
        kinds = list(QUOTA_KINDS)
    usage = await reset_monthly_quota(db, user.id, kinds=kinds)
    return AdminQuotaOut(
        month=usage["month"],
        story_used=usage["story_used"],
        story_limit=usage["story_limit"],
        clone_used=usage["clone_used"],
        clone_limit=usage["clone_limit"],
    )
