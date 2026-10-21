"""Admin read APIs for soft story series + outline_json."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.child import Child
from app.models.story import Story
from app.models.story_series import StorySeries
from app.models.user import User

router = APIRouter(prefix="/story-series", tags=["admin-series"])


class AdminSeriesListItem(BaseModel):
    id: int
    title: str
    status: str
    language: str
    theme: str | None
    episode_count: int
    user_id: int
    user_display_name: str | None = None
    child_id: int | None
    child_nickname: str | None = None
    stories_count: int = 0
    throughline: str | None = None
    created_at: str | None


class AdminSeriesListOut(BaseModel):
    items: list[AdminSeriesListItem]
    total: int
    page: int
    page_size: int


class AdminSeriesEpisodeStory(BaseModel):
    episode_no: int | None
    story_id: int
    title: str
    status: str


class AdminSeriesDetailOut(BaseModel):
    id: int
    title: str
    status: str
    language: str
    theme: str | None
    episode_count: int
    user_id: int
    user_display_name: str | None
    child_id: int | None
    child_nickname: str | None
    throughline: str | None = None
    cast_spine: list | dict | None = None
    threads: list | None = None
    episodes: list | None = None
    outline_json: str
    stories: list[AdminSeriesEpisodeStory] = Field(default_factory=list)
    created_at: str | None


def _parse_outline(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        return {}


def _throughline(outline: dict) -> str | None:
    t = outline.get("arc") or outline.get("throughline")
    return str(t).strip() if isinstance(t, str) and t.strip() else None


def _cast_spine(outline: dict) -> list | None:
    cast = outline.get("cast")
    if isinstance(cast, list):
        return cast
    legacy = outline.get("cast_spine")
    return legacy if isinstance(legacy, list) else None


@router.get("", response_model=AdminSeriesListOut)
async def list_series(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str | None = None,
    user_id: int | None = None,
    child_id: int | None = None,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminSeriesListOut:
    filters = []
    if status:
        filters.append(StorySeries.status == status.strip())
    if user_id is not None:
        filters.append(StorySeries.user_id == user_id)
    if child_id is not None:
        filters.append(StorySeries.child_id == child_id)

    count_q = select(func.count()).select_from(StorySeries)
    list_q = select(StorySeries).order_by(StorySeries.id.desc())
    if filters:
        count_q = count_q.where(*filters)
        list_q = list_q.where(*filters)

    total = int((await db.execute(count_q)).scalar_one())
    rows = (
        await db.execute(list_q.offset((page - 1) * page_size).limit(page_size))
    ).scalars().all()

    user_ids = {s.user_id for s in rows}
    child_ids = {s.child_id for s in rows if s.child_id is not None}
    series_ids = [s.id for s in rows]

    users: dict[int, User] = {}
    if user_ids:
        for u in (
            await db.execute(select(User).where(User.id.in_(user_ids)))
        ).scalars().all():
            users[u.id] = u

    children: dict[int, Child] = {}
    if child_ids:
        for c in (
            await db.execute(select(Child).where(Child.id.in_(child_ids)))
        ).scalars().all():
            children[c.id] = c

    story_counts: dict[int, int] = {}
    if series_ids:
        count_rows = (
            await db.execute(
                select(Story.series_id, func.count())
                .where(Story.series_id.in_(series_ids))
                .group_by(Story.series_id)
            )
        ).all()
        story_counts = {int(sid): int(n) for sid, n in count_rows if sid is not None}

    items = []
    for s in rows:
        outline = _parse_outline(s.outline_json)
        child = children.get(s.child_id) if s.child_id else None
        items.append(
            AdminSeriesListItem(
                id=s.id,
                title=s.title or outline.get("title") or "",
                status=s.status,
                language=s.language,
                theme=s.theme,
                episode_count=s.episode_count,
                user_id=s.user_id,
                user_display_name=(
                    users.get(s.user_id).display_name if s.user_id in users else None
                ),
                child_id=s.child_id,
                child_nickname=child.nickname if child else None,
                stories_count=story_counts.get(s.id, 0),
                throughline=_throughline(outline),
                created_at=s.created_at.isoformat() if s.created_at else None,
            )
        )
    return AdminSeriesListOut(
        items=items, total=total, page=page, page_size=page_size
    )


@router.get("/{series_id}", response_model=AdminSeriesDetailOut)
async def get_series(
    series_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AdminSeriesDetailOut:
    series = await db.get(StorySeries, series_id)
    if series is None:
        raise HTTPException(status_code=404, detail="Series not found")

    user = await db.get(User, series.user_id)
    child = await db.get(Child, series.child_id) if series.child_id else None
    outline = _parse_outline(series.outline_json)

    stories = (
        await db.execute(
            select(Story)
            .where(Story.series_id == series_id)
            .order_by(Story.episode_no.asc(), Story.id.asc())
        )
    ).scalars().all()

    return AdminSeriesDetailOut(
        id=series.id,
        title=series.title or str(outline.get("title") or ""),
        status=series.status,
        language=series.language,
        theme=series.theme,
        episode_count=series.episode_count,
        user_id=series.user_id,
        user_display_name=user.display_name if user else None,
        child_id=series.child_id,
        child_nickname=child.nickname if child else None,
        throughline=_throughline(outline),
        cast_spine=_cast_spine(outline),
        threads=outline.get("threads") if isinstance(outline.get("threads"), list) else None,
        episodes=outline.get("episodes") if isinstance(outline.get("episodes"), list) else None,
        outline_json=series.outline_json or "{}",
        stories=[
            AdminSeriesEpisodeStory(
                episode_no=st.episode_no,
                story_id=st.id,
                title=st.title or "",
                status=st.status,
            )
            for st in stories
        ],
        created_at=series.created_at.isoformat() if series.created_at else None,
    )
