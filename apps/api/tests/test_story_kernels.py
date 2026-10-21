"""Story kernel catalog: seed, select, soft dedup, admin list."""

from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.api.kernels import router as kernels_router
from app.core.db import get_db
from app.core.security import get_current_user, require_admin
from app.models.user import User
from app.services.story_kernels import (
    FOCUS_TO_AXIS,
    _seed_rows,
    age_stage_for_band,
    axis_for_focus,
    kernel_to_prompt_payload,
    select_story_kernel,
)


def test_seed_rows_cover_bands_and_axes():
    rows = _seed_rows()
    assert len(rows) >= 15
    stages = {r["age_stage"] for r in rows}
    assert "toddler_2_3" in stages
    assert "late_school_9_12" in stages
    assert all(r["focus_id"] in FOCUS_TO_AXIS for r in rows)
    assert all("禁止" in r["soft_guidance"] or "轻触" in r["soft_guidance"] for r in rows)


def test_age_stage_for_band():
    assert age_stage_for_band("2-3") == "toddler_2_3"
    assert age_stage_for_band("9-12") == "late_school_9_12"
    assert age_stage_for_band("preschool") == "preschool_3_5"


def test_axis_for_focus_and_slim_prompt_payload():
    assert axis_for_focus("curious_cause") == ("curiosity", "好奇")
    assert axis_for_focus("tiny_brave") == ("courage", "勇气")
    row = SimpleNamespace(
        id="k1",
        focus_id="curious_cause",
        axis="curiosity",
        name="小问题冒头",
        soft_guidance="长指导不要进 prompt",
        age_stage="preschool_3_5",
    )
    payload = kernel_to_prompt_payload(row)
    assert payload["axis_label"] == "好奇"
    assert "soft_guidance" not in payload
    assert "name" not in payload


@pytest.mark.asyncio
async def test_select_soft_dedup():
    a = MagicMock()
    a.id = "k_a"
    a.age_stage = "preschool_3_5"
    a.enabled = True
    b = MagicMock()
    b.id = "k_b"
    b.age_stage = "preschool_3_5"
    b.enabled = True

    class _Scalars:
        def all(self):
            return [a, b]

        def first(self):
            return None

    class _Result:
        def scalars(self):
            return _Scalars()

    class _Db:
        async def get(self, model, key):
            return None

        async def execute(self, _q):
            return _Result()

    with patch(
        "app.services.story_kernels.age_years_int_on", return_value=4
    ), patch(
        "app.services.story_kernels._recent_kernel_ids",
        AsyncMock(return_value={"k_a"}),
    ):
        picked = await select_story_kernel(
            _Db(),
            child_id=1,
            birth_date=date(2022, 10, 15),
            salt="fixed",
            episode_no=1,
            on=date(2026, 10, 15),
        )
    assert picked is not None
    assert picked.id == "k_b"


@pytest.mark.asyncio
async def test_admin_list_kernels():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    row = MagicMock()
    row.id = "tiny_brave_preschool_3_5"
    row.axis = "courage"
    row.name = "小小勇敢"
    row.soft_guidance = "轻触"
    row.age_stage = "preschool_3_5"
    row.focus_id = "tiny_brave"
    row.enabled = True
    row.sort_order = 10

    class _Scalars:
        def all(self):
            return [row]

    class _Result:
        def scalars(self):
            return _Scalars()

        def scalar_one(self):
            return 1

    class _Db:
        async def execute(self, _q):
            return _Result()

    async def _db():
        yield _Db()

    async def _admin():
        return "ops"

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = _admin

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/kernels")
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 1
    assert data["items"][0]["axis"] == "courage"


@pytest.mark.asyncio
async def test_public_list_kernels():
    app = FastAPI()
    app.include_router(kernels_router, prefix="/v1")

    row = SimpleNamespace(
        id="tiny_brave_preschool_3_5",
        axis="courage",
        name="小小勇敢",
        soft_guidance="轻触",
        age_stage="preschool_3_5",
        focus_id="tiny_brave",
        enabled=True,
        sort_order=10,
    )

    async def _db():
        yield MagicMock()

    async def _user():
        return User(id=1, display_name="t")

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = _user

    with patch(
        "app.api.kernels.suggest_kernels",
        AsyncMock(
            return_value=[
                {
                    "id": row.id,
                    "axis": row.axis,
                    "axis_label": "勇气",
                    "name": row.name,
                    "focus_id": row.focus_id,
                    "age_stage": row.age_stage,
                }
            ]
        ),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.get("/v1/kernels", params={"age_band": "3-5"})
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 1
    assert data["items"][0]["name"] == "小小勇敢"
