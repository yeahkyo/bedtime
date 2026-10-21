"""Kernel LLM generation: parse, normalize, mock admin generate."""

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.services.kernel_generation import (
    AXIS_IDS,
    build_kernel_gen_messages,
    normalize_to_rows,
    parse_kernel_gen_json,
)


def test_axes_catalog():
    assert "courage" in AXIS_IDS
    assert "curiosity" in AXIS_IDS
    assert len(AXIS_IDS) >= 8


def test_parse_and_normalize():
    items = parse_kernel_gen_json(
        '{"items":[{"id":"cou_p35_001","axis":"courage","name":"小小试探",'
        '"soft_guidance":"轻触勇气轴","focus_id":"tiny_brave"}]}'
    )
    assert len(items) == 1
    rows = normalize_to_rows(
        items + [{"name": "", "soft_guidance": "skip"}],
        age_stage="preschool_3_5",
        axis="courage",
        existing_ids=set(),
    )
    assert len(rows) == 1
    assert rows[0]["enabled"] is False
    assert rows[0]["focus_id"] == "tiny_brave"
    assert "禁止" in rows[0]["soft_guidance"]


def test_normalize_unknown_focus_falls_back():
    rows = normalize_to_rows(
        [{"name": "安心", "soft_guidance": "轻触安全感", "focus_id": "not_a_real_focus"}],
        age_stage="toddler_2_3",
        axis="security",
        existing_ids=set(),
    )
    assert rows[0]["focus_id"] == "secure_presence"


def test_build_messages_include_theory():
    system, user = build_kernel_gen_messages(
        age_stage="preschool_3_5",
        axis="courage",
        existing_names=["已有"],
        count=5,
    )
    assert "发展心理学" in system or "Erikson" in system
    assert "courage" in user
    assert "Erikson" in user
    assert "已有" in user


@pytest.mark.asyncio
async def test_admin_generate_mock():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    class _Db:
        def __init__(self):
            self.added = []

        async def get(self, model, key):
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

    db = _Db()

    async def _db():
        yield db

    async def _admin():
        return "ops"

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = _admin

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test", timeout=30) as client:
        res = await client.post(
            "/admin/kernels/generate",
            json={
                "age_stage": "preschool_3_5",
                "axis": "courage",
                "provider": "mock",
                "model": "ignored",
                "count": 3,
            },
        )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["created"] == 3
    assert data["axis"] == "courage"
    assert all(getattr(x, "enabled") is False for x in db.added)


@pytest.mark.asyncio
async def test_admin_generate_defaults():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _admin():
        return "ops"

    app.dependency_overrides[require_admin] = _admin
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/kernels/generate-defaults")
    assert res.status_code == 200
    data = res.json()
    assert "deepseek" in data["providers"]
    assert len(data["axes"]) >= 8
    assert len(data["age_stages"]) == 4
