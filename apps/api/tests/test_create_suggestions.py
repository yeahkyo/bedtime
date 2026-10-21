"""Public inspiration/element chips + story_element_id on create."""

from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.elements import router as elements_router
from app.api.kernels import router as kernels_router
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.schemas.common import StoryCreate
from app.services.story_elements import suggest_elements
from app.services.story_kernels import suggest_kernels


@pytest.mark.asyncio
async def test_suggest_elements_prefers_fresh_and_limits():
    a = MagicMock()
    a.id = "el_a"
    a.name = "露珠"
    a.age_stage = "preschool_3_5"
    a.subcategory_id = "water"
    a.subcategory = MagicMock(label_zh="水", id="water")
    b = MagicMock()
    b.id = "el_b"
    b.name = "影子"
    b.age_stage = "preschool_3_5"
    b.subcategory_id = "light"
    b.subcategory = MagicMock(label_zh="光", id="light")
    c = MagicMock()
    c.id = "el_c"
    c.name = "风"
    c.age_stage = "preschool_3_5"
    c.subcategory_id = "air"
    c.subcategory = MagicMock(label_zh="气", id="air")

    class _Scalars:
        def all(self):
            return [a, b, c]

    class _Result:
        def scalars(self):
            return _Scalars()

    class _Db:
        async def execute(self, _q):
            return _Result()

    with patch(
        "app.services.story_elements._recent_element_ids",
        AsyncMock(return_value={"el_a"}),
    ):
        items = await suggest_elements(
            _Db(), age_band="3-5", limit=2, child_id=1, salt="fixed"
        )
    assert len(items) == 2
    ids = {x["id"] for x in items}
    assert "el_a" not in ids
    assert ids <= {"el_b", "el_c"}


@pytest.mark.asyncio
async def test_suggest_kernels_limits():
    rows = []
    for i in range(5):
        k = MagicMock()
        k.id = f"k_{i}"
        k.axis = "courage"
        k.name = f"名{i}"
        k.focus_id = "tiny_brave"
        k.age_stage = "preschool_3_5"
        rows.append(k)

    with patch(
        "app.services.story_kernels.list_kernels_for_band",
        AsyncMock(return_value=rows),
    ), patch(
        "app.services.story_kernels._recent_kernel_ids",
        AsyncMock(return_value=set()),
    ):
        items = await suggest_kernels(
            MagicMock(), age_band="3-5", limit=3, child_id=9, salt="s"
        )
    assert len(items) == 3
    assert all("focus_id" in x and "name" in x for x in items)


@pytest.mark.asyncio
async def test_public_elements_and_kernels_routes():
    app = FastAPI()
    app.include_router(kernels_router, prefix="/v1")
    app.include_router(elements_router, prefix="/v1")

    user = User(id=1, display_name="u")

    async def _user():
        return user

    class _Db:
        async def get(self, model, key):
            return None

    async def _db():
        yield _Db()

    app.dependency_overrides[get_current_user] = _user
    app.dependency_overrides[get_db] = _db

    with patch(
        "app.api.kernels.suggest_kernels",
        AsyncMock(
            return_value=[
                {
                    "id": "k1",
                    "axis": "courage",
                    "axis_label": "勇气",
                    "name": "小小勇敢",
                    "focus_id": "tiny_brave",
                    "age_stage": "preschool_3_5",
                }
            ]
        ),
    ), patch(
        "app.api.elements.suggest_elements",
        AsyncMock(
            return_value=[
                {
                    "id": "el1",
                    "name": "露珠",
                    "subcategory": "水",
                    "age_stage": "preschool_3_5",
                }
            ]
        ),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            k = await client.get("/v1/kernels", params={"age_band": "3-5", "limit": 5})
            e = await client.get("/v1/elements", params={"age_band": "3-5", "limit": 5})
    assert k.status_code == 200
    assert k.json()["total"] == 1
    assert e.status_code == 200
    assert e.json()["items"][0]["name"] == "露珠"


def test_story_create_accepts_story_element_id():
    body = StoryCreate(
        child_id=1,
        theme="月亮",
        story_element_id="el_moon",
        development_focus="tiny_brave",
    )
    assert body.story_element_id == "el_moon"


@pytest.mark.asyncio
async def test_resolve_records_usage_for_user_pick():
    from app.services.story_elements import resolve_story_element_for_job

    row = MagicMock()
    row.id = "el_pick"
    row.name = "贝壳"
    row.description = "海边小壳"
    row.category_id = "nature_life"
    row.subcategory_id = "shore"
    row.category = MagicMock(label_zh="自然", id="nature_life")
    row.subcategory = MagicMock(label_zh="岸边", id="shore")

    recorded: list[str] = []

    class _Db:
        pass

    with patch(
        "app.services.story_elements.get_element_with_taxonomy",
        AsyncMock(return_value=row),
    ), patch(
        "app.services.story_elements._usage_exists_for_story",
        AsyncMock(return_value=False),
    ), patch(
        "app.services.story_elements.record_element_usage",
        AsyncMock(side_effect=lambda db, **kw: recorded.append(kw["element_id"])),
    ):
        payload = await resolve_story_element_for_job(
            _Db(),
            child_id=1,
            birth_date=date(2022, 1, 1),
            salt="x",
            episode_no=1,
            story_id=99,
            reuse_element_id="el_pick",
        )
    assert payload["id"] == "el_pick"
    assert recorded == ["el_pick"]
