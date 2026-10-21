"""Admin soft-series list/detail + story detail embeds outline."""

import json
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin


OUTLINE = {
    "title": "软草地",
    "throughline": "找到能跳舞的软草地",
    "cast_spine": [{"name": "棉棉", "move": "踮脚", "catchphrase": "轻轻跳"}],
    "episodes": [
        {
            "episode_no": 1,
            "focus_id": "tiny_brave",
            "premise": "出门找草地",
            "soft_promise": "会看见一小片软草",
        }
    ],
}


@pytest.mark.asyncio
async def test_admin_get_series_detail():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    series = SimpleNamespace(
        id=3,
        title="软草地",
        status="active",
        language="zh",
        theme="草地",
        episode_count=4,
        user_id=1,
        child_id=1,
        outline_json=json.dumps(OUTLINE, ensure_ascii=False),
        created_at=None,
    )
    user = SimpleNamespace(id=1, display_name="Dev")
    child = SimpleNamespace(id=1, nickname="岛岛")
    story = SimpleNamespace(
        id=38, series_id=3, episode_no=1, title="第一集", status="ready"
    )

    class _Scalars:
        def __init__(self, rows):
            self._rows = rows

        def all(self):
            return self._rows

    class _Db:
        async def get(self, model, pk):
            name = getattr(model, "__tablename__", None) or getattr(
                model, "__name__", str(model)
            )
            if name == "story_series" or "StorySeries" in str(model):
                return series if pk == 3 else None
            if name == "users" or "User" in str(model):
                return user
            if name == "children" or "Child" in str(model):
                return child
            return None

        async def execute(self, _q):
            class _R:
                def scalars(self_inner):
                    return _Scalars([story])

            return _R()

    async def _db():
        return _Db()

    async def _admin():
        return "ops"

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = _admin

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        detail = await client.get("/admin/story-series/3")
        assert detail.status_code == 200, detail.text
        d = detail.json()
        assert d["throughline"] == "找到能跳舞的软草地"
        assert d["episodes"][0]["premise"] == "出门找草地"
        assert d["stories"][0]["story_id"] == 38
        assert d["child_nickname"] == "岛岛"


@pytest.mark.asyncio
async def test_admin_story_detail_embeds_series():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    series = SimpleNamespace(
        id=3,
        title="软草地",
        status="active",
        episode_count=4,
        outline_json=json.dumps(OUTLINE, ensure_ascii=False),
    )
    story = MagicMock()
    story.id = 38
    story.title = "第一集"
    story.body = "正文"
    story.status = "ready"
    story.progress = "ready"
    story.language = "zh"
    story.theme = "草地"
    story.soft_hook = None
    story.user_id = 1
    story.child_id = 1
    story.voice_id = None
    story.story_provider = "deepseek"
    story.speech_provider = "fishaudio"
    story.duration_minutes = 5
    story.series_id = 3
    story.episode_no = 1
    story.audio = None
    story.error_message = None
    story.params_json = "{}"
    story.episode_plan_json = None
    story.metrics_json = None
    story.created_at = None

    class _Result:
        def scalar_one_or_none(self):
            return story

    class _Db:
        async def execute(self, _q):
            return _Result()

        async def get(self, model, pk):
            if "User" in str(model):
                return SimpleNamespace(display_name="Dev")
            if "StorySeries" in str(model) or getattr(model, "__tablename__", "") == "story_series":
                return series if pk == 3 else None
            return None

    async def _db():
        return _Db()

    async def _admin():
        return "ops"

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = _admin

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/stories/38")
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["series_id"] == 3
    assert data["series"]["throughline"] == "找到能跳舞的软草地"
    assert data["series"]["episodes"][0]["premise"] == "出门找草地"
