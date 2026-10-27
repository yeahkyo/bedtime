"""Admin monthly quota reset clears Redis counters (enforcement path)."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.config import Settings, clear_settings_cache
from app.core.db import get_db
from app.core.security import require_admin
from app.services.quota import reset_monthly_quota, usage_summary


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


@pytest.mark.asyncio
async def test_usage_summary_respects_explicit_redis_zero():
    """Admin reset sets Redis to 0; must not fall back to ledger totals."""
    redis = AsyncMock()
    redis.get = AsyncMock(side_effect=lambda key: b"0" if ":story:" in key else None)
    db = AsyncMock()
    db.execute = AsyncMock(
        return_value=MagicMock(
            all=MagicMock(return_value=[("story", 99), ("clone", 2)])
        )
    )
    with patch("app.services.quota.get_redis", AsyncMock(return_value=redis)), patch(
        "app.services.quota.get_settings",
        return_value=Settings(monthly_story_quota=15, monthly_clone_quota=3),
    ), patch("app.services.quota._month_prefix", AsyncMock(return_value="2026-10")):
        summary = await usage_summary(db, user_id=1)
    assert summary["story_used"] == 0
    assert summary["clone_used"] == 2  # missing redis → ledger


@pytest.mark.asyncio
async def test_reset_monthly_quota_sets_redis_zero():
    redis = AsyncMock()
    redis.set = AsyncMock()
    redis.get = AsyncMock(return_value=b"0")
    db = AsyncMock()
    with patch("app.services.quota.get_redis", AsyncMock(return_value=redis)), patch(
        "app.services.quota.get_settings",
        return_value=Settings(monthly_story_quota=15, monthly_clone_quota=3),
    ), patch("app.services.quota._month_prefix", AsyncMock(return_value="2026-10")):
        out = await reset_monthly_quota(db, 7, kinds=["story"])
    assert redis.set.await_count == 1
    key, val = redis.set.await_args.args[:2]
    assert key == "quota:7:story:2026-10"
    assert val == 0
    assert out["story_used"] == 0


@pytest.mark.asyncio
async def test_admin_quota_reset_endpoint():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    user = MagicMock()
    user.id = 3
    user.deleted_at = None

    class _Db:
        async def get(self, _model, user_id):
            return user if user_id == 3 else None

    async def _db_override():
        yield _Db()

    async def _admin_override():
        return "admin"

    app.dependency_overrides[get_db] = _db_override
    app.dependency_overrides[require_admin] = _admin_override

    with patch(
        "app.api.admin.users.reset_monthly_quota",
        AsyncMock(
            return_value={
                "month": "2026-10",
                "story_used": 0,
                "story_limit": 15,
                "clone_used": 0,
                "clone_limit": 3,
            }
        ),
    ) as reset_fn:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            ok = await client.post(
                "/admin/users/3/quota/reset", json={"kinds": ["story"]}
            )
            assert ok.status_code == 200
            assert ok.json()["story_used"] == 0
            reset_fn.assert_awaited_once()

            missing = await client.post("/admin/users/999/quota/reset", json={})
            assert missing.status_code == 404
