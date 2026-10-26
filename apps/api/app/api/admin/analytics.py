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
from app.services.analytics_engagement import (
    ACTIVITY_EVENT_NAMES,
    MAX_ENGAGEMENT_RANGE_DAYS,
    clamp_engagement_range,
    compute_engagement,
)
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


class DauPointOut(BaseModel):
    date: date
    users: int


class RetentionCohortOut(BaseModel):
    cohort_date: date
    cohort_size: int
    d1: float | None
    d7: float | None
    d30: float | None


class AnalyticsEngagementOut(BaseModel):
    from_date: date
    to_date: date
    as_of: date
    max_range_days: int
    dau: list[DauPointOut]
    retention: list[RetentionCohortOut]
    avg_dau: float | None
    avg_d1: float | None
    avg_d7: float | None
    avg_d30: float | None


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
    # Same 90-day clamp as /engagement so Admin cards share one window.
    from_date, to_date = clamp_engagement_range(from_date, to_date)
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


@router.get("/engagement", response_model=AnalyticsEngagementOut)
async def analytics_engagement(
    from_date: date = Query(alias="from"),
    to_date: date = Query(alias="to"),
    _admin: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> AnalyticsEngagementOut:
    """DAU + D1/D7/D30 retention (UTC days). Range clamped to 90 days."""
    from_date, to_date = clamp_engagement_range(from_date, to_date)
    as_of = datetime.now(timezone.utc).date()
    # Need activity through to_date+30 (or as_of) for mature D30.
    activity_end = min(to_date + timedelta(days=30), as_of)
    start, end = _day_bounds_utc(from_date, activity_end)

    rows = (
        await db.execute(
            select(AnalyticsEvent.user_id, AnalyticsEvent.created_at).where(
                AnalyticsEvent.created_at >= start,
                AnalyticsEvent.created_at < end,
                AnalyticsEvent.name.in_(tuple(ACTIVITY_EVENT_NAMES)),
            )
        )
    ).all()

    user_days: set[tuple[int, date]] = set()
    for user_id, created_at in rows:
        if user_id is None or created_at is None:
            continue
        ts = created_at
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        else:
            ts = ts.astimezone(timezone.utc)
        user_days.add((int(user_id), ts.date()))

    result = compute_engagement(
        user_days, from_date, to_date, as_of=as_of
    )
    return AnalyticsEngagementOut(
        from_date=result.from_date,
        to_date=result.to_date,
        as_of=result.as_of,
        max_range_days=MAX_ENGAGEMENT_RANGE_DAYS,
        dau=[DauPointOut(date=p.day, users=p.users) for p in result.dau],
        retention=[
            RetentionCohortOut(
                cohort_date=c.cohort_date,
                cohort_size=c.cohort_size,
                d1=c.d1,
                d7=c.d7,
                d30=c.d30,
            )
            for c in result.retention
        ],
        avg_dau=result.avg_dau,
        avg_d1=result.avg_d1,
        avg_d7=result.avg_d7,
        avg_d30=result.avg_d30,
    )
