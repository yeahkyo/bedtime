"""Public waitlist join + admin list."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.api.waitlist import router as waitlist_router
from app.core.db import get_db
from app.core.security import require_admin
from app.models.waitlist import WaitlistLead


def _app() -> FastAPI:
    app = FastAPI()
    app.include_router(waitlist_router, prefix="/v1")
    app.include_router(admin_router, prefix="/admin")
    return app


def _db_session(*, existing: WaitlistLead | None = None) -> MagicMock:
    session = MagicMock()
    session.add = MagicMock()
    session.commit = AsyncMock()

    async def _execute(stmt):  # noqa: ARG001
        result = MagicMock()
        result.scalar_one_or_none = MagicMock(return_value=existing)
        result.scalar_one = MagicMock(return_value=1 if existing else 0)
        result.scalars = MagicMock(
            return_value=MagicMock(all=MagicMock(return_value=[existing] if existing else []))
        )
        return result

    session.execute = AsyncMock(side_effect=_execute)
    return session


@pytest.mark.asyncio
async def test_waitlist_rejects_invalid_email():
    app = _app()
    session = _db_session()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    with patch("app.api.waitlist.rate_limit_auth_ip", new_callable=AsyncMock):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/public/waitlist",
                json={"email": "not-an-email", "device": "ios"},
            )
    assert res.status_code == 400
    assert res.json()["detail"] == "Invalid email"
    session.add.assert_not_called()


@pytest.mark.asyncio
async def test_waitlist_rejects_invalid_device():
    app = _app()
    session = _db_session()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    with patch("app.api.waitlist.rate_limit_auth_ip", new_callable=AsyncMock):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/public/waitlist",
                json={"email": "a@example.com", "device": "windows"},
            )
    assert res.status_code == 400
    assert res.json()["detail"] == "Invalid device"


@pytest.mark.asyncio
async def test_waitlist_creates_new_lead():
    app = _app()
    session = _db_session(existing=None)

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    with patch("app.api.waitlist.rate_limit_auth_ip", new_callable=AsyncMock):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/public/waitlist",
                json={"email": " Parent@Example.com ", "device": "android", "note": " hi "},
            )
    assert res.status_code == 200
    body = res.json()
    assert body["ok"] is True
    assert body["email"] == "parent@example.com"
    assert body["created"] is True
    session.add.assert_called_once()
    lead = session.add.call_args[0][0]
    assert isinstance(lead, WaitlistLead)
    assert lead.email == "parent@example.com"
    assert lead.device == "android"
    assert lead.note == "hi"
    session.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_waitlist_dedupes_by_email():
    existing = WaitlistLead(id=1, email="parent@example.com", device="ios", note=None)
    app = _app()
    session = _db_session(existing=existing)

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    with patch("app.api.waitlist.rate_limit_auth_ip", new_callable=AsyncMock):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/public/waitlist",
                json={"email": "parent@example.com", "device": "both", "note": "again"},
            )
    assert res.status_code == 200
    body = res.json()
    assert body["created"] is False
    assert existing.device == "both"
    assert existing.note == "again"
    session.add.assert_not_called()
    session.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_waitlist_race_unique_falls_back_to_update():
    from sqlalchemy.exc import IntegrityError

    raced = WaitlistLead(id=9, email="race@example.com", device="ios", note=None)
    app = _app()
    session = MagicMock()
    session.add = MagicMock()
    session.rollback = AsyncMock()
    commits = 0

    async def _commit():
        nonlocal commits
        commits += 1
        if commits == 1:
            raise IntegrityError("stmt", {}, Exception("duplicate"))

    session.commit = AsyncMock(side_effect=_commit)

    async def _execute(stmt):  # noqa: ARG001
        result = MagicMock()
        # first select: no row; after race: existing row
        if commits == 0:
            result.scalar_one_or_none = MagicMock(return_value=None)
        else:
            result.scalar_one_or_none = MagicMock(return_value=raced)
        return result

    session.execute = AsyncMock(side_effect=_execute)

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    with patch("app.api.waitlist.rate_limit_auth_ip", new_callable=AsyncMock):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/public/waitlist",
                json={"email": "race@example.com", "device": "android", "note": "won"},
            )
    assert res.status_code == 200
    assert res.json()["created"] is False
    assert raced.device == "android"
    assert raced.note == "won"
    session.rollback.assert_awaited_once()
    assert commits == 2


@pytest.mark.asyncio
async def test_admin_waitlist_requires_auth():
    app = _app()
    session = _db_session()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/waitlist")
    assert res.status_code in (401, 403)


@pytest.mark.asyncio
async def test_admin_waitlist_lists():
    existing = WaitlistLead(id=3, email="a@b.co", device="ios", note="n")
    app = _app()
    session = _db_session(existing=existing)

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "admin"
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/waitlist")
    assert res.status_code == 200
    body = res.json()
    assert body["total"] == 1
    assert body["items"][0]["email"] == "a@b.co"
