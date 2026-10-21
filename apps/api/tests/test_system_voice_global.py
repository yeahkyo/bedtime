"""Global system voice catalog (user_id NULL)."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.models.voice import SYSTEM_VOICE_NAME, Voice
from app.services.system_voice import (
    _pick_catalog_voice,
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


def test_pick_catalog_prefers_configured_voice_id():
    a = SimpleNamespace(id=1, provider_voice_id="other")
    b = SimpleNamespace(id=2, provider_voice_id="longanyang")
    assert _pick_catalog_voice([a, b], configured_id="longanyang") is b
    assert _pick_catalog_voice([a, b], configured_id="") is a


@pytest.mark.asyncio
async def test_ensure_system_voice_creates_global_row():
    session = MagicMock()
    session.execute = AsyncMock(
        side_effect=[
            _exec_all([]),  # no global catalog
            _exec_one(None),  # no legacy
        ]
    )
    session.add = MagicMock()
    session.commit = AsyncMock()
    session.refresh = AsyncMock()

    user = SimpleNamespace(id=3)

    with (
        patch(
            "app.services.system_voice.resolve_speech_provider_name",
            AsyncMock(return_value="aliyun"),
        ),
        patch(
            "app.services.system_voice.speech_default_voice_id",
            return_value="longanyang",
        ),
        patch(
            "app.services.system_voice.resolve_speech_model",
            AsyncMock(return_value="cosyvoice-v3-flash"),
        ),
        patch(
            "app.services.system_voice.env_speech_model",
            return_value="cosyvoice-v3-flash",
        ),
    ):
        voice = await ensure_system_voice(session, user, "aliyun")

    assert isinstance(voice, Voice)
    assert voice.user_id is None
    assert voice.kind == "system"
    assert voice.provider == "aliyun"
    assert voice.provider_voice_id == "longanyang"
    assert voice.name == SYSTEM_VOICE_NAME
    session.add.assert_called_once()
    session.commit.assert_awaited()


@pytest.mark.asyncio
async def test_ensure_system_voice_tolerates_multiple_globals():
    keep = SimpleNamespace(
        id=2,
        user_id=None,
        kind="system",
        provider="aliyun",
        provider_voice_id="longanyang",
        speech_model="cosyvoice-v3-flash",
        name=SYSTEM_VOICE_NAME,
    )
    other = SimpleNamespace(
        id=1,
        user_id=None,
        kind="system",
        provider="aliyun",
        provider_voice_id="other-voice",
        speech_model="cosyvoice-v3.5-flash",
        name="别的柔声",
    )
    session = MagicMock()
    session.execute = AsyncMock(return_value=_exec_all([other, keep]))
    session.commit = AsyncMock()
    session.refresh = AsyncMock()

    with (
        patch(
            "app.services.system_voice.speech_default_voice_id",
            return_value="longanyang",
        ),
        patch(
            "app.services.system_voice.resolve_speech_model",
            AsyncMock(return_value="cosyvoice-v3-flash"),
        ),
        patch(
            "app.services.system_voice.env_speech_model",
            return_value="cosyvoice-v3-flash",
        ),
    ):
        voice = await ensure_system_voice(session, SimpleNamespace(id=1), "aliyun")

    assert voice is keep
    # Must not rewrite the other catalog voice id onto the chosen row.
    assert keep.provider_voice_id == "longanyang"
    session.add.assert_not_called()


@pytest.mark.asyncio
async def test_ensure_system_voice_promotes_legacy_row():
    legacy = SimpleNamespace(
        user_id=9,
        kind="system",
        provider="aliyun",
        provider_voice_id="longanyang",
        speech_model=None,
        name=SYSTEM_VOICE_NAME,
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

    with (
        patch(
            "app.services.system_voice.speech_default_voice_id",
            return_value="longanyang",
        ),
        patch(
            "app.services.system_voice.resolve_speech_model",
            AsyncMock(return_value=None),
        ),
        patch(
            "app.services.system_voice.env_speech_model",
            return_value="",
        ),
    ):
        voice = await ensure_system_voice(session, SimpleNamespace(id=9), "aliyun")

    assert voice is legacy
    assert legacy.user_id is None
    session.commit.assert_awaited()


def test_apply_voice_speed_overrides_prefs():
    from app.providers.base import VoiceSettings
    from app.services.voice_settings import apply_voice_speed

    base = VoiceSettings(speed=1.0, stability=0.65, style=0.05, similarity_boost=0.75)
    voice = SimpleNamespace(speed_tier="slow")
    out = apply_voice_speed(base, voice)
    assert out.speed == 0.85
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
                "speed_tier": "slow",
            },
        )
    assert res.status_code == 201, res.text
    body = res.json()
    assert body["user_id"] is None
    assert body["name"] == "全局柔声"
    assert body["speed_tier"] == "slow"
    assert created and created[0].user_id is None
    assert created[0].speed_tier == "slow"
