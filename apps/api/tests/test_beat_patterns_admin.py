"""Beat pattern seed catalog + admin list/patch."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.providers.story_prompt import select_beat_pattern
from app.services.beat_patterns import (
    apply_catalog,
    apply_seed_catalog_fallback,
    seed_beat_patterns_if_empty,
    seed_rows_from_constants,
)


def test_seed_rows_cover_constants():
    rows = seed_rows_from_constants()
    ids = {r["id"] for r in rows}
    assert "two_gates" in ids
    assert "settle_ladder" in ids
    assert any(r["focus_ids"] for r in rows)


@pytest.mark.asyncio
async def test_seed_skips_reinsert_when_already_done():
    class _Db:
        async def execute(self, _q):
            class _R:
                def scalar_one(self):
                    return 0

            return _R()

        async def commit(self):
            raise AssertionError("should not insert when seed already done")

    with patch(
        "app.services.beat_patterns._beat_seed_done", AsyncMock(return_value=True)
    ), patch("app.services.beat_patterns.apply_seed_catalog_fallback") as fallback:
        inserted = await seed_beat_patterns_if_empty(_Db())
        assert inserted == 0
        fallback.assert_called_once()


def test_runtime_catalog_drives_select():
    apply_catalog(
        [
            {
                "id": "custom_frame",
                "label": "自定义",
                "lineage": "test",
                "theme_tags": ["钥匙"],
                "slots": "wish, snag, try_1, try_2, turn_ok",
                "instruction": "try_2 必须升级",
                "escalation": "升级",
                "focus_ids": ["gentle_agency"],
                "enabled": True,
                "sort_order": 1,
            }
        ]
    )
    picked = select_beat_pattern(
        "gentle_agency", theme="发光钥匙", episode_no=1, salt="x"
    )
    assert picked["id"] == "custom_frame"
    apply_seed_catalog_fallback()


@pytest.mark.asyncio
async def test_admin_list_beats_override():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    row = MagicMock()
    row.id = "two_gates"
    row.label = "两道小门槛"
    row.lineage = "fairy"
    row.theme_tags_json = '["找"]'
    row.slots = "wish, snag, try_1, try_2, turn_ok"
    row.instruction = "x"
    row.escalation = "y"
    row.focus_ids_json = '["tiny_brave"]'
    row.enabled = True
    row.sort_order = 0

    class _Result:
        def scalars(self):
            return self

        def all(self):
            return [row]

    class _Db:
        async def execute(self, _q):
            return _Result()

        async def get(self, _model, beat_id):
            return row if beat_id == "two_gates" else None

        async def commit(self):
            return None

        async def refresh(self, _obj):
            return None

    async def _db():
        yield _Db()

    async def _admin():
        return "admin"

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = _admin

    with patch(
        "app.api.admin.beats.seed_beat_patterns_if_empty", AsyncMock(return_value=0)
    ), patch("app.api.admin.beats.refresh_beat_catalog", AsyncMock(return_value=1)):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.get("/admin/beats")
            assert res.status_code == 200
            body = res.json()
            assert body["total"] == 1
            assert body["items"][0]["id"] == "two_gates"

            patched = await client.patch(
                "/admin/beats/two_gates",
                json={"label": "两道门槛改", "enabled": True},
            )
            assert patched.status_code == 200
