"""Element LLM generation: parse, normalize, taxonomy, mock admin generate."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.services.element_age_stages import suggested_counts
from app.services.element_generation import (
    build_element_gen_messages,
    normalize_to_rows,
    parse_element_gen_json,
)
from app.services.story_elements import SEED_CATEGORIES, SEED_SUBCATEGORIES


def test_canonical_taxonomy_shape():
    assert len(SEED_CATEGORIES) == 4
    assert len(SEED_SUBCATEGORIES) == 13
    assert all(s.get("generation_brief") and s.get("id_prefix") for s in SEED_SUBCATEGORIES)
    cats = {c["id"] for c in SEED_CATEGORIES}
    assert cats == {
        "nature_life",
        "matter_mechanics",
        "body_senses",
        "time_space",
    }
    assert all(s["category_id"] in cats for s in SEED_SUBCATEGORIES)
    # Retired SEL / philosophy-oriented ids must be gone.
    retired = {
        "nature_senses",
        "emotion_self",
        "social_boundary",
        "philosophy_life",
        "patience_wait",
        "self_identity",
        "personal_space",
        "collab_empathy",
        "life_change",
        "plant_growth",
    }
    assert not (cats & retired)
    assert not ({s["id"] for s in SEED_SUBCATEGORIES} & retired)


def test_suggested_counts_shares():
    counts = suggested_counts(100)
    assert counts["toddler_2_3"] == 20
    assert counts["preschool_3_5"] == 40
    assert counts["early_school_6_8"] == 25
    assert counts["late_school_9_12"] == 15
    assert sum(counts.values()) == 100


def test_parse_element_gen_json_array_and_wrapped():
    items = parse_element_gen_json(
        '[{"id":"plg_001","name":"种子","description":"种子吸水后萌发"}]'
    )
    assert len(items) == 1
    wrapped = parse_element_gen_json(
        '```json\n{"items":[{"id":"plg_002","name":"根系","description":"根吸收水分"}]}\n```'
    )
    assert wrapped[0]["id"] == "plg_002"


def test_normalize_to_rows_stage_and_enabled():
    rows = normalize_to_rows(
        [
            {
                "id": "plg_001",
                "name": "种子发芽",
                "description": "种子吸水后萌发",
            },
            {
                "motif_id": "xx_9",
                "title": "旧字段标题",
                "cognition": {"fact": "事实", "child_metaphor": "隐喻"},
            },
            {"name": "", "description": "skip"},
        ],
        category_id="nature_life",
        subcategory_id="plant_forms",
        id_prefix="plg",
        age_stage="toddler_2_3",
        existing_ids={"plg_001"},
    )
    assert len(rows) == 2
    assert rows[0]["id"] == "plg_002"  # conflict → next free
    assert rows[0]["enabled"] is True
    assert rows[0]["age_stage"] == "toddler_2_3"
    assert rows[0]["name"] == "种子发芽"
    assert rows[1]["id"].startswith("plg_")
    assert rows[1]["name"] == "旧字段标题"
    assert rows[1]["description"] == "事实"
    assert "philosophy" not in rows[1]


def test_build_messages_include_stage_and_brief():
    system, user = build_element_gen_messages(
        category_label="自然与生命现象",
        subcategory_label="植物形态与生长",
        id_prefix="plg",
        generation_brief="根系与水分",
        age_stage="preschool_3_5",
        existing_names=["已有名称"],
        count=10,
    )
    assert "禁止说教" in system or "不是童话编剧" in system
    assert "plg" in user
    assert "根系与水分" in user
    assert "已有名称" in user
    assert "preschool_3_5" in user


@pytest.mark.asyncio
async def test_upsert_canonical_taxonomy():
    from app.services.story_elements import upsert_canonical_taxonomy

    store: dict[str, object] = {}

    class _Scalars:
        def __init__(self, rows):
            self._rows = rows

        def all(self):
            return self._rows

    class _Result:
        def __init__(self, rows):
            self._rows = rows

        def scalars(self):
            return _Scalars(self._rows)

    class _Db:
        async def get(self, model, key):
            return store.get((model.__name__, key))

        async def execute(self, _q):
            # Prune queries: return no obsolete rows in unit test store.
            return _Result([])

        async def flush(self):
            return None

        async def commit(self):
            return None

        def add(self, obj):
            store[(type(obj).__name__, obj.id)] = obj

        async def delete(self, obj):
            store.pop((type(obj).__name__, obj.id), None)

    result = await upsert_canonical_taxonomy(_Db())
    assert result["categories"] == 4
    assert result["subcategories"] == 13
    assert ("StoryElementSubcategory", "plant_forms") in store
    sub = store[("StoryElementSubcategory", "plant_forms")]
    assert sub.id_prefix == "plg"
    assert sub.generation_brief
    assert ("StoryElementCategory", "nature_life") in store


@pytest.mark.asyncio
async def test_admin_generate_mock():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    sub = SimpleNamespace(
        id="plant_forms",
        category_id="nature_life",
        label_zh="植物形态与生长",
        generation_brief="根系与水分",
        id_prefix="plg",
    )
    cat = SimpleNamespace(id="nature_life", label_zh="自然与生命现象")

    class _Db:
        def __init__(self):
            self.added = []

        async def get(self, model, key):
            name = model.__name__
            if name == "StoryElementSubcategory" and key == "plant_forms":
                return sub
            if name == "StoryElementCategory" and key == "nature_life":
                return cat
            if name == "StoryElement":
                return None
            return None

        async def execute(self, _q):
            class _R:
                def all(self):
                    return []

            return _R()

        def add(self, obj):
            self.added.append(obj)

        async def commit(self):
            return None

        async def flush(self):
            return None

    db = _Db()

    async def _db():
        yield db

    async def _admin():
        return "ops"

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = _admin

    with patch(
        "app.api.admin.elements.upsert_canonical_taxonomy", AsyncMock(return_value={})
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test", timeout=30) as client:
            res = await client.post(
                "/admin/elements/generate",
                json={
                    "subcategory_id": "plant_forms",
                    "age_stage": "preschool_3_5",
                    "provider": "mock",
                    "model": "ignored",
                    "count": 3,
                },
            )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["created"] == 3
    assert data["provider"] == "mock"
    assert data["age_stage"] == "preschool_3_5"
    assert data["total"] == 3
    assert all(getattr(x, "enabled") is True for x in db.added)
    assert all(getattr(x, "age_stage") == "preschool_3_5" for x in db.added)


@pytest.mark.asyncio
async def test_admin_generate_defaults():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _admin():
        return "ops"

    app.dependency_overrides[require_admin] = _admin
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/elements/generate-defaults")
    assert res.status_code == 200
    data = res.json()
    assert "deepseek" in data["providers"]
    assert "deepseek" in data["defaults"]
    assert len(data["age_stages"]) == 4
    assert data["stage_targets"]["preschool_3_5"] == 40
    assert data["stage_targets"]["late_school_9_12"] == 15
