"""Admin voices API + speech model resolution from Voice."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.services.provider_settings import resolve_speech_model


@pytest.mark.asyncio
async def test_resolve_speech_model_prefers_voice_model():
    with patch(
        "app.services.provider_settings.get_runtime_overrides",
        AsyncMock(return_value={"speech_model": "global-override"}),
    ):
        assert (
            await resolve_speech_model("aliyun", voice_model="cosyvoice-v3-plus")
            == "cosyvoice-v3-plus"
        )


@pytest.mark.asyncio
async def test_resolve_speech_model_falls_back_to_runtime_when_voice_empty():
    with patch(
        "app.services.provider_settings.get_runtime_overrides",
        AsyncMock(return_value={"speech_model": "global-override"}),
    ):
        assert await resolve_speech_model("aliyun", voice_model="") == "global-override"
        assert await resolve_speech_model("aliyun", voice_model=None) == "global-override"


@pytest.mark.asyncio
async def test_admin_voice_patch_updates_speech_model():
    from types import SimpleNamespace

    voice = SimpleNamespace(
        id=1,
        user_id=9,
        name="枕边柔声",
        kind="system",
        language="zh",
        provider="aliyun",
        provider_voice_id="longanyang",
        speech_model=None,
        speed_tier="medium",
        created_at=None,
    )
    user = SimpleNamespace(id=9, display_name="Ada", deleted_at=None)

    session = MagicMock()
    session.get = AsyncMock(side_effect=lambda model, pk: {
        ("Voice", 1): voice,
        ("User", 9): user,
    }.get((getattr(model, "__name__", ""), pk)))
    session.commit = AsyncMock()
    session.refresh = AsyncMock()

    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "admin"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        patched = await client.patch(
            "/admin/voices/1",
            json={"speech_model": "cosyvoice-v3-flash", "name": "阿里云柔声"},
        )
        assert patched.status_code == 200, patched.text
        assert patched.json()["speech_model"] == "cosyvoice-v3-flash"
        assert voice.speech_model == "cosyvoice-v3-flash"
        assert voice.name == "阿里云柔声"

        cleared = await client.patch("/admin/voices/1", json={"speech_model": ""})
        assert cleared.status_code == 200
        assert cleared.json()["speech_model"] is None


@pytest.mark.asyncio
async def test_admin_voice_preview_returns_mpeg():
    from types import SimpleNamespace

    from app.providers.base import VoiceSettings

    voice = SimpleNamespace(
        id=1,
        user_id=9,
        name="枕边柔声",
        kind="system",
        language="zh",
        provider="mock",
        provider_voice_id="mock_system_voice",
        speech_model=None,
        speed_tier="slow",
        created_at=None,
    )

    session = MagicMock()
    session.get = AsyncMock(return_value=voice)

    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "admin"

    speeds: list[float] = []

    async def _fake_synth(tts, text, voice_id, settings, **kwargs):
        assert isinstance(settings, VoiceSettings)
        assert "夜深了" in text or "Night" in text
        speeds.append(float(settings.speed))
        return b"ID3fake-preview-mp3", text

    transport = ASGITransport(app=app)
    with patch(
        "app.api.admin.voices.synthesize_with_prosody",
        AsyncMock(side_effect=_fake_synth),
    ):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            saved = await client.post("/admin/voices/1/preview", json={})
            assert saved.status_code == 200, saved.text
            assert saved.headers["content-type"].startswith("audio/mpeg")
            assert saved.content.startswith(b"ID3")
            # Saved-voice preview uses the row's speed_tier (slow → 0.85).
            assert speeds[-1] == 0.85

            adhoc = await client.post(
                "/admin/voices/preview",
                json={
                    "provider": "mock",
                    "provider_voice_id": "mock_system_voice",
                    "language": "zh",
                    "speed_tier": "fast",
                },
            )
            assert adhoc.status_code == 200
            assert adhoc.content.startswith(b"ID3")
            assert speeds[-1] == 1.1
