from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.security import require_admin
from app.models.story import Story
from app.models.user import User
from app.models.voice import Voice
from app.services.storage import storage_service

router = APIRouter(prefix="/stories", tags=["admin-stories"])


class AdminStoryListItem(BaseModel):
    id: int
    title: str
    status: str
    progress: str | None
    language: str
    theme: str | None
    user_id: int
    user_display_name: str | None = None
    child_id: int | None
    story_provider: str | None
    speech_provider: str | None
    duration_minutes: int
    created_at: str | None
    error_message: str | None = None


class AdminStoryListOut(BaseModel):
    items: list[AdminStoryListItem]
    total: int
    page: int
    page_size: int


class AdminStoryDetailOut(BaseModel):
    id: int
    title: str
    body: str
    status: str
    progress: str | None
    language: str
    theme: str | None
    soft_hook: str | None
    user_id: int
    user_display_name: str | None
    child_id: int | None
    voice_id: int | None
    voice_name: str | None
    story_provider: str | None
    speech_provider: str | None
    duration_minutes: int
    series_id: int | None
    episode_no: int | None
    audio_url: str | None
    error_message: str | None
    params_json: str | None
    episode_plan_json: str | None = None
    created_at: str | None


@router.get("", response_model=AdminStoryListOut)
async def list_stories(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str | None = None,
    user_id: int | None = None,
    story_provider: str | None = None,
    speech_provider: str | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminStoryListOut:
    filters = []
    if status:
        filters.append(Story.status == status.strip())
    if user_id is not None:
        filters.append(Story.user_id == user_id)
    if story_provider:
        filters.append(Story.story_provider == story_provider.strip().lower())
    if speech_provider:
        filters.append(Story.speech_provider == speech_provider.strip().lower())

    count_q = select(func.count()).select_from(Story)
    list_q = select(Story).order_by(Story.id.desc())
    if filters:
        count_q = count_q.where(*filters)
        list_q = list_q.where(*filters)

    total = int((await db.execute(count_q)).scalar_one())
    rows = (
        await db.execute(list_q.offset((page - 1) * page_size).limit(page_size))
    ).scalars().all()

    user_ids = {s.user_id for s in rows}
    users: dict[int, User] = {}
    if user_ids:
        for u in (
            await db.execute(select(User).where(User.id.in_(user_ids)))
        ).scalars().all():
            users[u.id] = u

    items = [
        AdminStoryListItem(
            id=s.id,
            title=s.title or "",
            status=s.status,
            progress=s.progress,
            language=s.language,
            theme=s.theme,
            user_id=s.user_id,
            user_display_name=users.get(s.user_id).display_name if s.user_id in users else None,
            child_id=s.child_id,
            story_provider=s.story_provider,
            speech_provider=s.speech_provider,
            duration_minutes=s.duration_minutes,
            created_at=s.created_at.isoformat() if s.created_at else None,
            error_message=s.error_message,
        )
        for s in rows
    ]
    return AdminStoryListOut(items=items, total=total, page=page, page_size=page_size)


@router.get("/{story_id}", response_model=AdminStoryDetailOut)
async def get_story(
    story_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminStoryDetailOut:
    story = (
        await db.execute(
            select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
        )
    ).scalar_one_or_none()
    if story is None:
        raise HTTPException(status_code=404, detail="Story not found")
    user = await db.get(User, story.user_id)
    voice_name = None
    if story.voice_id is not None:
        voice = await db.get(Voice, story.voice_id)
        if voice is not None:
            voice_name = voice.name
    audio_url = None
    if story.audio:
        audio_url = await storage_service.presigned_url(story.audio.object_key)
    return AdminStoryDetailOut(
        id=story.id,
        title=story.title or "",
        body=story.body or "",
        status=story.status,
        progress=story.progress,
        language=story.language,
        theme=story.theme,
        soft_hook=story.soft_hook,
        user_id=story.user_id,
        user_display_name=user.display_name if user else None,
        child_id=story.child_id,
        voice_id=story.voice_id,
        voice_name=voice_name,
        story_provider=story.story_provider,
        speech_provider=story.speech_provider,
        duration_minutes=story.duration_minutes,
        series_id=story.series_id,
        episode_no=story.episode_no,
        audio_url=audio_url,
        error_message=story.error_message,
        params_json=story.params_json,
        episode_plan_json=story.episode_plan_json,
        created_at=story.created_at.isoformat() if story.created_at else None,
    )
