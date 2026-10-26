"""Admin voices API + speech model resolution from Voice."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.services.provider_settings import resolve_speech_model


def _voice(**kwargs):
    base = dict(
        id=1,
        user_id=9,
        name="枕边柔声",
        kind="system",
        language="zh",
        provider="aliyun",
        provider_voice_id="longanyang",
        speech_model=None,
        speed_tier="medium",
        speed=1.0,
        enabled=True,
        sort_order=0,
        preview_text=None,
        preview_object_key=None,
        preview_generated_at=None,
        created_at=None,
    )
    base.update(kwargs)
    return SimpleNamespace(**base)


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
async def test_resolve_speech_model_falls_back_to_env_when_voice_empty():
    with patch(
        "app.services.provider_settings.env_speech_model",
        return_value="cosyvoice-v3-flash",
    ):
        assert await resolve_speech_model("aliyun", voice_model="") == "cosyvoice-v3-flash"
        assert await resolve_speech_model("aliyun", voice_model=None) == "cosyvoice-v3-flash"


@pytest.mark.asyncio
async def test_admin_voice_patch_updates_speech_model_and_enabled():
    voice = _voice()
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

    with patch(
        "app.api.admin.voices.storage_service.presigned_url",
        AsyncMock(return_value=None),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            patched = await client.patch(
                "/admin/voices/1",
                json={
                    "speech_model": "cosyvoice-v3-flash",
                    "name": "阿里云柔声",
                    "description": "温柔低语，适合哄睡",
                    "enabled": False,
                    "sort_order": 10,
                },
            )
            assert patched.status_code == 200, patched.text
            body = patched.json()
            assert body["speech_model"] == "cosyvoice-v3-flash"
            assert body["description"] == "温柔低语，适合哄睡"
            assert body["enabled"] is False
            assert body["sort_order"] == 10
            assert voice.enabled is False
            assert voice.description == "温柔低语，适合哄睡"
            assert voice.sort_order == 10

            cleared = await client.patch("/admin/voices/1", json={"speech_model": ""})
            assert cleared.status_code == 200
            assert cleared.json()["speech_model"] is None


@pytest.mark.asyncio
async def test_admin_voice_preview_generate_persists():
    from app.providers.base import VoiceSettings

    voice = _voice(
        provider="mock",
        provider_voice_id="mock_system_voice",
        speed=0.85,
        user_id=None,
    )
    session = MagicMock()

    async def _get(model, pk):
        if getattr(model, "__name__", "") == "Voice" and pk == 1:
            return voice
        return None

    session.get = AsyncMock(side_effect=_get)
    session.commit = AsyncMock()
    session.refresh = AsyncMock()

    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "admin"

    async def _fake_synth(tts, text, voice_id, settings, **kwargs):
        from app.services.narration_prosody import SynthesizeWithProsodyResult

        assert isinstance(settings, VoiceSettings)
        assert text
        return SynthesizeWithProsodyResult(
            audio=b"ID3fake-preview-mp3",
            display=text,
            speak_text=text,
            ssml=None,
            used_ssml=False,
        )

    put = AsyncMock(return_value="voices/1/preview.mp3")
    transport = ASGITransport(app=app)
    synth_patch = patch(
        "app.api.admin.voices.synthesize_with_prosody",
        AsyncMock(side_effect=_fake_synth),
    )
    put_patch = patch("app.api.admin.voices.storage_service.put_bytes", put)
    url_patch = patch("app.api.admin.voices.storage_service.presigned_url", AsyncMock(return_value="/media/voices/1/preview.mp3"))
    with synth_patch, put_patch, url_patch:
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            gen = await client.post(
                "/admin/voices/1/preview/generate",
                json={"text": "自定义试听一句。"},
            )
            assert gen.status_code == 200, gen.text
            body = gen.json()
            assert body["preview_text"] == "自定义试听一句。"
            assert body["preview_audio_url"] == "/media/voices/1/preview.mp3"
            assert voice.preview_object_key == "voices/1/preview.mp3"
            put.assert_awaited_once()

            # Adhoc live preview still works (not persisted).
            adhoc = await client.post(
                "/admin/voices/preview",
                json={
                    "provider": "mock",
                    "provider_voice_id": "mock_system_voice",
                    "language": "zh",
                    "speed": 1.1,
                    "text": "Night soft",
                },
            )
            assert adhoc.status_code == 200
            assert adhoc.content.startswith(b"ID3")


@pytest.mark.asyncio
async def test_admin_get_stored_preview():
    voice = _voice(preview_object_key="voices/1/preview.mp3")
    session = MagicMock()
    session.get = AsyncMock(return_value=voice)

    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "admin"

    with patch(
        "app.api.admin.voices.storage_service.get_bytes",
        AsyncMock(return_value=b"ID3stored"),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.get("/admin/voices/1/preview")
            assert res.status_code == 200
            assert res.content == b"ID3stored"
