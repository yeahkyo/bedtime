"""Admin product analytics summary (self-hosted events + story status)."""

from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.analytics import AnalyticsEvent
from app.models.story import Story
from app.services.analytics_events import ALLOWED_EVENT_NAMES

router = APIRouter(prefix="/analytics", tags=["admin-analytics"])

_SUMMARY_EVENT_NAMES = (
    "register_success",
    "login_success",
    "generate_tap",
    "story_ready",
    "story_failed",
    "playback_complete",
    "quota_hit",
    "app_open",
    "create_open",
    "player_open",
)


class AnalyticsSummaryOut(BaseModel):
    from_date: date
    to_date: date
    event_counts: dict[str, int]
    story_status_counts: dict[str, int]
    listen_rate: float | None


def _day_bounds_utc(from_date: date, to_date: date) -> tuple[datetime, datetime]:
    start = datetime.combine(from_date, time.min, tzinfo=timezone.utc)
    # Inclusive end date → exclusive next midnight.
    end = datetime.combine(to_date + timedelta(days=1), time.min, tzinfo=timezone.utc)
    return start, end


@router.get("/summary", response_model=AnalyticsSummaryOut)
async def analytics_summary(
    from_date: date = Query(alias="from"),
    to_date: date = Query(alias="to"),
    _admin: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AnalyticsSummaryOut:
    if to_date < from_date:
        from_date, to_date = to_date, from_date
    start, end = _day_bounds_utc(from_date, to_date)

    event_counts = {name: 0 for name in _SUMMARY_EVENT_NAMES}
    rows = (
        await db.execute(
            select(AnalyticsEvent.name, func.count())
            .where(
                AnalyticsEvent.created_at >= start,
                AnalyticsEvent.created_at < end,
                AnalyticsEvent.name.in_(tuple(ALLOWED_EVENT_NAMES)),
            )
            .group_by(AnalyticsEvent.name)
        )
    ).all()
    for name, count in rows:
        if name in event_counts:
            event_counts[name] = int(count)

    story_status_counts: dict[str, int] = {}
    story_rows = (
        await db.execute(
            select(Story.status, func.count())
            .where(Story.created_at >= start, Story.created_at < end)
            .group_by(Story.status)
        )
    ).all()
    for status, count in story_rows:
        story_status_counts[str(status)] = int(count)

    ready = event_counts.get("story_ready", 0)
    complete = event_counts.get("playback_complete", 0)
    listen_rate = (complete / ready) if ready > 0 else None

    return AnalyticsSummaryOut(
        from_date=from_date,
        to_date=to_date,
        event_counts=event_counts,
        story_status_counts=story_status_counts,
        listen_rate=listen_rate,
    )
