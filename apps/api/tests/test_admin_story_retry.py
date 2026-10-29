"""Admin story retry reuses enqueue_story_retry and does not charge quota."""

import inspect
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.api.admin import stories as admin_stories
from app.api import stories as user_stories
from app.core.db import get_db
from app.core.security import require_admin


def test_admin_retry_does_not_charge_quota():
    src = inspect.getsource(admin_stories.admin_retry_story)
    assert "check_and_increment" not in src
    assert "enqueue_story_retry" in src


@pytest.mark.asyncio
async def test_admin_retry_failed_story_smoke():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    story = MagicMock()
    story.id = 41
    story.user_id = 7
    story.status = "failed"
    story.progress = "failed"
    story.error_message = "Story generation failed"
    story.child_id = 1
    story.title = ""
    story.body = ""
    story.theme = "月亮"
    story.language = "zh"
    story.duration_minutes = 10
    story.voice_id = 1
    story.story_provider = "doubao"
    story.story_model = "x"
    story.speech_provider = "aliyun"
    story.speech_model = "y"
    story.series_id = None
    story.episode_no = None
    story.audio = None
    story.soft_hook = None
    story.params_json = "{}"
    story.episode_plan_json = None
    story.metrics_json = None
    story.prompts_json = None
    story.created_at = None

    owner = MagicMock()
    owner.id = 7
    owner.display_name = "Ops User"

    class _Result:
        def __init__(self, row):
            self._row = row

        def scalar_one_or_none(self):
            return self._row

        def scalar_one(self):
            return self._row

    class _Db:
        async def execute(self, _stmt):
            return _Result(story)

        async def get(self, model, pk):
            name = getattr(model, "__name__", "")
            if name == "User" and pk == 7:
                return owner
            return None

        async def commit(self):
            pass

        async def refresh(self, _row):
            pass

    async def _db():
        yield _Db()

    app.dependency_overrides[require_admin] = lambda: "ops"
    app.dependency_overrides[get_db] = _db

    async def _enqueue(_db, **kwargs):
        assert kwargs["force_full"] is True
        assert kwargs["owner"].id == 7
        story.status = "generating"
        story.progress = "queued"
        story.error_message = None
        return story

    with (
        patch.object(admin_stories, "is_retryable_story", return_value=True),
        patch.object(admin_stories, "enqueue_story_retry", side_effect=_enqueue) as enq,
        patch.object(
            admin_stories,
            "get_story",
            new=AsyncMock(
                return_value=admin_stories.AdminStoryDetailOut(
                    id=41,
                    title="",
                    body="",
                    status="generating",
                    progress="queued",
                    language="zh",
                    theme="月亮",
                    soft_hook=None,
                    user_id=7,
                    user_display_name="Ops User",
                    child_id=1,
                    voice_id=1,
                    voice_name=None,
                    story_provider="doubao",
                    story_model="x",
                    speech_provider="aliyun",
                    speech_model="y",
                    duration_minutes=10,
                    series_id=None,
                    episode_no=None,
                    audio_url=None,
                    error_message=None,
                    params_json="{}",
                    created_at=None,
                )
            ),
        ),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/admin/stories/41/retry",
                json={"force_full": True},
            )
    assert res.status_code == 202
    assert res.json()["status"] == "generating"
    enq.assert_awaited_once()
    assert user_stories.enqueue_story_retry is not None
