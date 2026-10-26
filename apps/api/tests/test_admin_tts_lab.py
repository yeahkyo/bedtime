"""Admin TTS lab prepare endpoint (no live provider call)."""

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
async def test_tts_lab_prepare_fish_break(monkeypatch):
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    voice = SimpleNamespace(
        id=9,
        name="软声",
        provider="fishaudio",
        provider_voice_id="ref_x",
        speech_model="s2-pro",
    )

    class _Db:
        async def get(self, model, pk):
            if getattr(model, "__name__", "") == "Voice" and pk == 9:
                return voice
            return None

    async def _db():
        yield _Db()

    async def _resolve(provider, voice_model=None):
        return voice_model or "s2-pro"

    monkeypatch.setattr(
        "app.api.admin.tts_lab.resolve_speech_model",
        _resolve,
    )

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "ops"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/admin/tts-lab/prepare",
            json={
                "text": "今晚月亮亮亮的。小猫抬起爪子。\n\n慢慢睡着了。",
                "voice_id": 9,
                "prosody": "auto",
            },
        )
    assert res.status_code == 200, res.text
    data = res.json()
    assert data["provider"] == "fishaudio"
    assert data["voice_name"] == "软声"
    assert "[break]" in data["speak_text"] or "[long-break]" in data["speak_text"]
    assert data["used_ssml"] is False
