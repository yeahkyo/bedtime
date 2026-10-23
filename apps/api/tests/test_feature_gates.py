"""Phase-1 feature gates: soft series + voice clone."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient

from app.api import stories as stories_mod
from app.api.voices import router as voices_router
from app.core.config import Settings
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.voice import Voice
from app.schemas.common import StoryCreate


def _voice(**kwargs) -> Voice:
    defaults = dict(
        id=1,
        user_id=None,
        name="系统",
        kind="system",
        provider="fishaudio",
        provider_voice_id="x",
        speech_model=None,
        speed_tier="medium",
        speed=1.0,
        language="zh",
        enabled=True,
        preview_object_key=None,
        description=None,
        sort_order=0,
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
async def test_clone_rejected_when_feature_off():
    app = FastAPI()
    app.include_router(voices_router, prefix="/v1")
    session = MagicMock()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=1)

    transport = ASGITransport(app=app)
    with patch(
        "app.api.voices.get_settings",
        return_value=Settings(feature_voice_clone=False),
    ):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/voices/clone",
                data={"consent": "true", "name": "爸", "language": "zh"},
                files={"file": ("a.wav", b"x" * 2000, "audio/wav")},
            )
    assert res.status_code == 403
    assert res.json()["detail"] == "Voice clone is not available"


@pytest.mark.asyncio
async def test_list_voices_hides_clones_when_feature_off():
    system = _voice(id=1, kind="system", user_id=None)
    clone = _voice(id=2, kind="clone", user_id=7, name="爸")
    session = MagicMock()
    session.execute = AsyncMock(return_value=_exec_rows([system, clone]))

    app = FastAPI()
    app.include_router(voices_router, prefix="/v1")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=7)

    transport = ASGITransport(app=app)
    with (
        patch(
            "app.api.voices.get_settings",
            return_value=Settings(feature_voice_clone=False),
        ),
        patch(
            "app.api.voices.storage_service.presigned_url",
            AsyncMock(return_value=None),
        ),
    ):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.get("/v1/voices")
    assert res.status_code == 200
    body = res.json()
    assert len(body) == 1
    assert body[0]["kind"] == "system"


@pytest.mark.asyncio
async def test_soft_series_rejected_when_feature_off():
    body = StoryCreate(
        child_id=1,
        theme="月亮",
        soft_series_mode=True,
    )
    with patch(
        "app.api.stories.get_settings",
        return_value=Settings(feature_soft_series=False),
    ):
        with pytest.raises(HTTPException) as ei:
            await stories_mod._resolve_series_state(
                MagicMock(), SimpleNamespace(id=1), body
            )
    assert ei.value.status_code == 403
    assert ei.value.detail == "Soft series is not available"


@pytest.mark.asyncio
async def test_series_id_rejected_when_feature_off():
    body = StoryCreate(child_id=1, theme="月亮", series_id=9)
    with patch(
        "app.api.stories.get_settings",
        return_value=Settings(feature_soft_series=False),
    ):
        with pytest.raises(HTTPException) as ei:
            await stories_mod._resolve_series_state(
                MagicMock(), SimpleNamespace(id=1), body
            )
    assert ei.value.status_code == 403
