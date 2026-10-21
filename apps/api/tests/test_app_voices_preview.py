"""App /voices list exposes persisted preview URLs."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.voices import router as voices_router
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.voice import Voice


def _voice(**kwargs) -> Voice:
    defaults = dict(
        id=1,
        user_id=None,
        name="枕边柔声",
        kind="system",
        provider="aliyun",
        provider_voice_id="longanyang",
        speech_model="cosyvoice-v3-flash",
        speed_tier="medium",
        language="zh",
        enabled=True,
        preview_object_key=None,
        preview_text=None,
        preview_generated_at=None,
    )
    defaults.update(kwargs)
    v = Voice(
        name=defaults["name"],
        kind=defaults["kind"],
        provider=defaults["provider"],
        provider_voice_id=defaults["provider_voice_id"],
        language=defaults["language"],
    )
    for k, val in defaults.items():
        setattr(v, k, val)
    return v


def _exec_rows(rows: list):
    r = MagicMock()
    r.scalars.return_value.all.return_value = rows
    return r


@pytest.mark.asyncio
async def test_list_voices_includes_preview_url():
    enabled = _voice(id=1, preview_object_key="voices/1/preview.mp3")

    session = MagicMock()
    session.execute = AsyncMock(return_value=_exec_rows([enabled]))
    session.get = AsyncMock(return_value=enabled)

    app = FastAPI()
    app.include_router(voices_router, prefix="/v1")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=7)

    transport = ASGITransport(app=app)
    url_mock = AsyncMock(return_value="/media/voices/1/preview.mp3")
    bytes_mock = AsyncMock(return_value=b"ID3preview")
    with (
        patch("app.api.voices.storage_service.presigned_url", url_mock),
        patch("app.api.voices.storage_service.get_bytes", bytes_mock),
    ):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.get("/v1/voices")
            assert res.status_code == 200, res.text
            body = res.json()
            assert len(body) == 1
            assert body[0]["id"] == 1
            assert body[0]["preview_audio_url"] == "/media/voices/1/preview.mp3"
            assert body[0]["enabled"] is True

            preview = await client.get("/v1/voices/1/preview")
            assert preview.status_code == 200
            assert preview.content == b"ID3preview"
            assert preview.headers["content-type"].startswith("audio/mpeg")
