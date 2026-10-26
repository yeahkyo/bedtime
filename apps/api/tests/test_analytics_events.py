"""Product analytics ingest: whitelist, ownership, auth, idempotency."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.analytics import router as analytics_router
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.analytics import AnalyticsEvent


def _session_with_existing_keys(keys: set[str] | None = None) -> MagicMock:
    session = MagicMock()
    session.add_all = MagicMock()
    session.commit = AsyncMock()

    existing = keys or set()

    async def _execute(stmt):  # noqa: ARG001
        result = MagicMock()
        result.all = MagicMock(return_value=[(k,) for k in existing])
        return result

    session.execute = AsyncMock(side_effect=_execute)
    return session


@pytest.mark.asyncio
async def test_ingest_rejects_unknown_event_name():
    app = FastAPI()
    app.include_router(analytics_router, prefix="/v1")
    session = _session_with_existing_keys()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=7)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/v1/analytics/events",
            json={"events": [{"name": "not_a_real_event"}]},
        )
    assert res.status_code == 400
    assert "Unknown event name" in res.json()["detail"]
    session.add_all.assert_not_called()


@pytest.mark.asyncio
async def test_ingest_accepts_whitelisted_and_sets_user_id():
    app = FastAPI()
    app.include_router(analytics_router, prefix="/v1")
    session = _session_with_existing_keys()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=42)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/v1/analytics/events",
            json={
                "events": [
                    {
                        "name": "generate_tap",
                        "props": {"duration": 5},
                        "platform": "ios",
                        "app_version": "1.0.0+1",
                        "idempotency_key": "gen-1",
                    },
                    {
                        "name": "story_ready",
                        "story_id": 99,
                        "idempotency_key": "ready-99",
                    },
                ]
            },
        )
    assert res.status_code == 200
    assert res.json() == {"accepted": 2, "duplicates": 0}
    session.add_all.assert_called_once()
    rows = session.add_all.call_args[0][0]
    assert len(rows) == 2
    assert all(isinstance(r, AnalyticsEvent) for r in rows)
    assert all(r.user_id == 42 for r in rows)
    assert rows[0].name == "generate_tap"
    assert rows[0].idempotency_key == "gen-1"
    assert rows[1].story_id == 99
    session.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_ingest_skips_duplicate_idempotency_keys():
    app = FastAPI()
    app.include_router(analytics_router, prefix="/v1")
    session = _session_with_existing_keys({"already-sent"})

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=42)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/v1/analytics/events",
            json={
                "events": [
                    {"name": "app_open", "idempotency_key": "already-sent"},
                    {"name": "app_open", "idempotency_key": "fresh-1"},
                    {"name": "app_open", "idempotency_key": "fresh-1"},
                ]
            },
        )
    assert res.status_code == 200
    body = res.json()
    assert body["accepted"] == 1
    assert body["duplicates"] == 2
    rows = session.add_all.call_args[0][0]
    assert len(rows) == 1
    assert rows[0].idempotency_key == "fresh-1"


@pytest.mark.asyncio
async def test_ingest_requires_auth():
    app = FastAPI()
    app.include_router(analytics_router, prefix="/v1")

    async def _db():
        yield MagicMock()

    app.dependency_overrides[get_db] = _db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/v1/analytics/events",
            json={"events": [{"name": "app_open"}]},
        )
    assert res.status_code in (401, 403)
