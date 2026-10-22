"""Global system voice catalog (user_id NULL)."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException

from app.models.voice import SYSTEM_VOICE_NAME, Voice
from app.services.system_voice import (
    ensure_system_voice,
    voice_accessible_to_user,
)


def _exec_all(rows: list):
    r = MagicMock()
    r.scalars.return_value.all.return_value = rows
    r.scalar_one_or_none.return_value = None
    return r


def _exec_one(row):
    r = MagicMock()
    r.scalars.return_value.all.return_value = []
    r.scalar_one_or_none.return_value = row
    return r


def test_voice_accessible_global_and_owned():
    global_v = SimpleNamespace(user_id=None)
    owned = SimpleNamespace(user_id=7)
    other = SimpleNamespace(user_id=8)
    assert voice_accessible_to_user(global_v, 7) is True
    assert voice_accessible_to_user(owned, 7) is True
    assert voice_accessible_to_user(other, 7) is False


@pytest.mark.asyncio
async def test_ensure_system_voice_picks_enabled_catalog_any_provider():
    keep = SimpleNamespace(
        id=5,
        user_id=None,
        kind="system",
        provider="aliyun",
        provider_voice_id="longhuhu_v3",
        speech_model="cosyvoice-v3-flash",
        name="呼呼",
        enabled=True,
    )
    disabled = SimpleNamespace(
        id=1,
        user_id=None,
        kind="system",
        provider="volc",
        provider_voice_id="zh_female_vv",
        speech_model=None,
        name="Gentle System",
        enabled=False,
    )
    session = MagicMock()
    session.execute = AsyncMock(return_value=_exec_all([disabled, keep]))
    session.commit = AsyncMock()
    session.refresh = AsyncMock()

    voice = await ensure_system_voice(session, SimpleNamespace(id=1), "volc")
    assert voice is keep
    session.add.assert_not_called()


@pytest.mark.asyncio
async def test_ensure_system_voice_503_when_catalog_all_disabled():
    """Disabled global catalog must not promote legacy per-user system rows."""
    disabled = SimpleNamespace(
        id=1,
        user_id=None,
        kind="system",
        provider="aliyun",
        provider_voice_id="x",
        speech_model=None,
        name="off",
        enabled=False,
    )
    legacy = SimpleNamespace(
        id=2,
        user_id=9,
        kind="system",
        provider="volc",
        provider_voice_id="legacy",
        speech_model=None,
        name="legacy",
        enabled=True,
    )
    session = MagicMock()
    session.execute = AsyncMock(return_value=_exec_all([disabled]))
    session.add = MagicMock()
    session.commit = AsyncMock()

    with pytest.raises(HTTPException) as ei:
        await ensure_system_voice(session, SimpleNamespace(id=1))
    assert ei.value.status_code == 503
    assert "No enabled system voice" in ei.value.detail
    assert legacy.user_id == 9
    session.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_ensure_system_voice_promotes_legacy_row():
    legacy = SimpleNamespace(
        user_id=9,
        kind="system",
        provider="aliyun",
        provider_voice_id="longanyang",
        speech_model=None,
        name=SYSTEM_VOICE_NAME,
        enabled=True,
    )
    session = MagicMock()
    session.execute = AsyncMock(
        side_effect=[
            _exec_all([]),
            _exec_one(legacy),
        ]
    )
    session.commit = AsyncMock()
    session.refresh = AsyncMock()

    with patch(
        "app.services.system_voice.env_speech_model",
        return_value="",
    ):
        voice = await ensure_system_voice(session, SimpleNamespace(id=9))

    assert voice is legacy
    assert legacy.user_id is None
    session.commit.assert_awaited()


def test_apply_voice_speed_overrides_prefs():
    from app.providers.base import VoiceSettings
    from app.services.voice_settings import apply_voice_speed

    base = VoiceSettings(speed=1.0, stability=0.65, style=0.05, similarity_boost=0.75)
    voice = SimpleNamespace(speed=0.9, speed_tier="medium")
    out = apply_voice_speed(base, voice)
    assert out.speed == 0.9
    assert out.stability == 0.65


@pytest.mark.asyncio
async def test_admin_create_system_voice_is_global():
    from fastapi import FastAPI
    from httpx import ASGITransport, AsyncClient

    from app.api.admin import router as admin_router
    from app.core.db import get_db
    from app.core.security import require_admin

    created: list[Voice] = []

    session = MagicMock()

    async def _commit():
        for v in created:
            if getattr(v, "id", None) is None:
                v.id = 42
                v.created_at = None

    session.add = MagicMock(side_effect=lambda v: created.append(v))
    session.commit = AsyncMock(side_effect=_commit)
    session.refresh = AsyncMock()

    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[require_admin] = lambda: "admin"

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/admin/voices",
            json={
                "name": "全局柔声",
                "kind": "system",
                "provider": "aliyun",
                "provider_voice_id": "longanyang",
                "speech_model": "cosyvoice-v3.5-flash",
                "speed": 0.85,
            },
        )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["user_id"] is None
    assert body["name"] == "全局柔声"
    assert body["speed"] == 0.85
    assert created and created[0].user_id is None
    assert created[0].speed == 0.85
