"""Admin recompute of TTS speak_text / ssml from stored story body."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin


@pytest.mark.asyncio
async def test_admin_recompute_tts_input_fish():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    story = MagicMock()
    story.id = 42
    story.body = "今晚月亮亮亮的。小猫抬起爪子。\n\n它轻轻闭上眼睛。"
    story.speech_provider = "fishaudio"
    story.speech_model = "s2-pro"
    story.voice_id = 7

    voice = SimpleNamespace(
        provider_voice_id="ref_abc",
        provider="fishaudio",
        speech_model="s2-pro",
    )

    class _Db:
        async def get(self, model, pk):
            name = getattr(model, "__name__", str(model))
            if name == "Story" and pk == 42:
                return story
            if name == "Voice" and pk == 7:
                return voice
            return None

    async def _db():
        yield _Db()

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "ops"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/stories/42/tts-input")
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["story_id"] == 42
    assert data["source"] == "recomputed"
    assert data["provider"] == "fishaudio"
    assert data["model"] == "s2-pro"
    assert data["used_ssml"] is False
    assert data["ssml"] is None
    assert "[break]" in data["speak_text"] or "[long-break]" in data["speak_text"]
    assert "[pause]" not in data["speak_text"]


@pytest.mark.asyncio
async def test_admin_recompute_tts_input_empty_body():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    story = MagicMock()
    story.id = 1
    story.body = "  "
    story.speech_provider = "fishaudio"
    story.speech_model = None
    story.voice_id = None

    class _Db:
        async def get(self, model, pk):
            if getattr(model, "__name__", "") == "Story":
                return story
            return None

    async def _db():
        yield _Db()

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "ops"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get("/admin/stories/1/tts-input")
    assert res.status_code == 400
