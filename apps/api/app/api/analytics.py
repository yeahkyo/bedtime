"""Client product analytics ingest (self-hosted; not Umeng)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.analytics import AnalyticsEvent
from app.models.user import User
from app.services.analytics_events import (
    ALLOWED_EVENT_NAMES,
    MAX_EVENTS_PER_REQUEST,
    normalize_idempotency_key,
    serialize_props,
)

router = APIRouter(prefix="/analytics", tags=["analytics"])


class AnalyticsEventIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    story_id: int | None = None
    props: dict[str, Any] | None = None
    client_ts: datetime | None = None
    app_version: str | None = Field(default=None, max_length=64)
    platform: str | None = Field(default=None, max_length=32)
    idempotency_key: str | None = Field(default=None, max_length=64)


class AnalyticsEventsBody(BaseModel):
    events: list[AnalyticsEventIn] = Field(min_length=1, max_length=MAX_EVENTS_PER_REQUEST)


class AnalyticsEventsOut(BaseModel):
    accepted: int
    duplicates: int = 0


@router.post("/events", response_model=AnalyticsEventsOut)
async def ingest_events(
    body: AnalyticsEventsBody,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AnalyticsEventsOut:
    # Pre-normalize keys; reject unknown names early.
    prepared: list[tuple[AnalyticsEventIn, str | None]] = []
    for item in body.events:
        name = item.name.strip()
        if name not in ALLOWED_EVENT_NAMES:
            raise HTTPException(status_code=400, detail=f"Unknown event name: {name}")
        prepared.append((item, normalize_idempotency_key(item.idempotency_key)))

    keys = [k for _, k in prepared if k]
    existing: set[str] = set()
    if keys:
        rows = (
            await db.execute(
                select(AnalyticsEvent.idempotency_key).where(
                    AnalyticsEvent.user_id == user.id,
                    AnalyticsEvent.idempotency_key.in_(keys),
                )
            )
        ).all()
        existing = {str(r[0]) for r in rows if r[0]}

    seen_in_batch: set[str] = set()
    to_insert: list[AnalyticsEvent] = []
    duplicates = 0
    for item, key in prepared:
        if key:
            if key in existing or key in seen_in_batch:
                duplicates += 1
                continue
            seen_in_batch.add(key)
        name = item.name.strip()
        to_insert.append(
            AnalyticsEvent(
                user_id=user.id,
                name=name,
                story_id=item.story_id,
                props_json=serialize_props(item.props),
                app_version=(item.app_version or "").strip() or None,
                platform=(item.platform or "").strip() or None,
                client_ts=item.client_ts,
                idempotency_key=key,
            )
        )

    if to_insert:
        db.add_all(to_insert)
        await db.commit()
    return AnalyticsEventsOut(accepted=len(to_insert), duplicates=duplicates)
