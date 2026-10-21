"""Story element catalog: age stage filter, soft dedup, prompt payload, admin."""

from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.providers.base import StoryRequest
from app.providers.story_prompt import build_plan_user_message, validate_episode_plan
from app.services.child_profile import age_years_int_on
from app.services.element_age_stages import age_stage_for_years, stages_matching_years
from app.services.story_elements import (
    SEED_CATEGORIES,
    SEED_SUBCATEGORIES,
    _stable_pick,
    element_to_prompt_payload,
    select_story_element,
)


def test_age_years_int_on():
    today = date(2026, 10, 15)
    assert age_years_int_on(date(2024, 10, 15), on=today) == 2
    assert age_years_int_on(date(2022, 1, 1), on=today) == 4
    assert age_years_int_on(None, on=today) == 4
    assert age_years_int_on(date(2027, 1, 1), on=today) == 0


def test_age_stage_mapping():
    assert age_stage_for_years(1) == "toddler_2_3"  # no infant stage
    assert age_stage_for_years(2) == "toddler_2_3"
    assert age_stage_for_years(4) == "preschool_3_5"
    assert age_stage_for_years(7) == "early_school_6_8"
    assert age_stage_for_years(10) == "late_school_9_12"
    assert age_stage_for_years(14) == "late_school_9_12"
    assert "toddler_2_3" in stages_matching_years(3)
    assert "preschool_3_5" in stages_matching_years(3)
    assert stages_matching_years(1) == ["toddler_2_3"]
    assert stages_matching_years(10) == ["late_school_9_12"]
    assert stages_matching_years(13) == ["late_school_9_12"]


def test_stable_pick_deterministic():
    a = SimpleNamespace(id="aaa")
    b = SimpleNamespace(id="bbb")
    c = SimpleNamespace(id="ccc")
    first = _stable_pick([a, b, c], "salt-1")
    again = _stable_pick([c, a, b], "salt-1")
    assert first.id == again.id
    other = _stable_pick([a, b, c], "salt-2")
    assert other.id in {"aaa", "bbb", "ccc"}


def test_element_prompt_payload_objective_only():
    row = SimpleNamespace(
        id="rain_makes_puddles",
        category_id="nature_life",
        subcategory_id="weather_water",
        name="水洼",
        description="雨点落到地面会汇在低处",
        age_stage="preschool_3_5",
        category=SimpleNamespace(label_zh="自然与生命现象"),
        subcategory=SimpleNamespace(label_zh="天气与水体"),
    )
    payload = element_to_prompt_payload(row)
    assert payload["id"] == "rain_makes_puddles"
    assert payload["name"] == "水洼"
    assert payload["description"]
    assert "philosophy" not in payload
    assert "topic" not in payload
    assert "age" not in payload
    assert "hook" not in str(payload).lower()


def test_plan_message_does_not_inject_tonight_element():
    """Simplified plan prompt no longer receives story_element."""
    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        story_element={
            "id": "rain_makes_puddles",
            "category": "自然与生命现象",
            "subcategory": "天气与水体",
            "name": "水洼",
            "description": "雨点落到地面会汇在低处",
            "usage_rule": "objective knowledge only",
        },
    )
    msg = build_plan_user_message(req)
    assert '"element"' not in msg
    assert "rain_makes_puddles" not in msg
    assert '"keywords"' in msg


def test_validate_plan_ignores_element_meta():
    plan = {
        "title": "标题",
        "theme": "雨后",
        "casts": [{"name": "豆豆", "desc": "蹲下看水洼"}],
        "beats": ["蹲下", "看水洼", "回家"],
        "shape": "小小探索",
    }
    out = validate_episode_plan(
        plan,
        story_element={"id": "rain_makes_puddles", "name": "水洼", "category": "自然"},
    )
    assert "eid" not in out
    assert out["casts"][0]["name"] == "豆豆"


@pytest.mark.asyncio
async def test_select_filters_by_age_stage():
    young = MagicMock()
    young.id = "young_only"
    young.age_stage = "toddler_2_3"
    young.enabled = True
    young.category = None
    young.subcategory = None

    class _Scalars:
        def all(self):
            return [young]

    class _Result:
        def scalars(self):
            return _Scalars()

    class _Db:
        async def execute(self, q):
            return _Result()

    with patch(
        "app.services.story_elements.age_years_int_on", return_value=2
    ), patch(
        "app.services.story_elements._recent_element_ids",
        AsyncMock(return_value=set()),
    ):
        picked = await select_story_element(
            _Db(),
            child_id=1,
            birth_date=date(2024, 4, 1),
            salt="x",
            episode_no=1,
            on=date(2026, 10, 15),
        )
    assert picked is not None
    assert picked.id == "young_only"


@pytest.mark.asyncio
async def test_select_soft_dedup_then_relax():
    a = MagicMock()
    a.id = "el_a"
    a.age_stage = "preschool_3_5"
    b = MagicMock()
    b.id = "el_b"
    b.age_stage = "preschool_3_5"

    class _Scalars:
        def all(self):
            return [a, b]

    class _Result:
        def scalars(self):
            return _Scalars()

    class _Db:
        async def execute(self, _q):
            return _Result()

    with patch(
        "app.services.story_elements.age_years_int_on", return_value=4
    ), patch(
        "app.services.story_elements._recent_element_ids",
        AsyncMock(return_value={"el_a"}),
    ):
        picked = await select_story_element(
            _Db(),
            child_id=1,
            birth_date=date(2022, 10, 15),
            salt="fixed",
            episode_no=1,
            on=date(2026, 10, 15),
        )
    assert picked is not None
    assert picked.id == "el_b"

    with patch(
        "app.services.story_elements.age_years_int_on", return_value=4
    ), patch(
        "app.services.story_elements._recent_element_ids",
        AsyncMock(return_value={"el_a", "el_b"}),
    ):
        picked2 = await select_story_element(
            _Db(),
            child_id=1,
            birth_date=date(2022, 10, 15),
            salt="fixed",
            episode_no=1,
            on=date(2026, 10, 15),
        )
    assert picked2 is not None
    assert picked2.id in {"el_a", "el_b"}


@pytest.mark.asyncio
async def test_canonical_taxonomy_covers_four_categories():
    cats = {c["id"] for c in SEED_CATEGORIES}
    assert cats == {
        "nature_life",
        "matter_mechanics",
        "body_senses",
        "time_space",
    }
    assert len(SEED_SUBCATEGORIES) == 13
    for s in SEED_SUBCATEGORIES:
        assert s["category_id"] in cats
        assert s.get("id_prefix")
        assert s.get("generation_brief")
        brief = s["generation_brief"]
        assert any(
            token in brief
            for token in ("禁止", "不要", "只写", "只描述", "不作")
        )


@pytest.mark.asyncio
async def test_admin_list_elements():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    row = MagicMock()
    row.id = "rain_makes_puddles"
    row.category_id = "nature_life"
    row.subcategory_id = "weather_water"
    row.name = "水洼"
    row.description = "雨点汇在低处"
    row.age_stage = "preschool_3_5"
    row.enabled = True
    row.category = SimpleNamespace(label_zh="自然与生命现象")
    row.subcategory = SimpleNamespace(label_zh="天气与水体")

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

    with patch(
        "app.api.admin.elements.upsert_canonical_taxonomy", AsyncMock(return_value={})
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.get("/admin/elements")
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 1
    assert data["items"][0]["id"] == "rain_makes_puddles"
    assert data["items"][0]["name"] == "水洼"
    assert data["items"][0]["category_label_zh"] == "自然与生命现象"


@pytest.mark.asyncio
async def test_resolve_reuse_skips_reselect():
    from app.services.story_elements import resolve_story_element_for_job

    row = MagicMock()
    row.id = "rain_makes_puddles"
    row.name = "水洼"
    row.description = "雨点汇在低处"
    row.age_stage = "preschool_3_5"
    row.category_id = "nature_life"
    row.subcategory_id = "weather_water"
    row.category = SimpleNamespace(label_zh="自然与生命现象")
    row.subcategory = SimpleNamespace(label_zh="天气与水体")

    with patch(
        "app.services.story_elements.get_element_with_taxonomy",
        AsyncMock(return_value=row),
    ), patch(
        "app.services.story_elements.select_story_element",
        AsyncMock(side_effect=AssertionError("should not reselect")),
    ), patch(
        "app.services.story_elements._usage_exists_for_story",
        AsyncMock(return_value=True),
    ), patch(
        "app.services.story_elements.record_element_usage",
        AsyncMock(side_effect=AssertionError("should not re-record")),
    ):
        payload = await resolve_story_element_for_job(
            MagicMock(),
            child_id=1,
            birth_date=date(2022, 1, 1),
            salt="x",
            episode_no=1,
            story_id=9,
            reuse_element_id="rain_makes_puddles",
        )
    assert payload is not None
    assert payload["id"] == "rain_makes_puddles"
    assert payload["name"] == "水洼"
