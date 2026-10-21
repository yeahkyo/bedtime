"""Runtime story/speech model overrides."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.core.config import Settings
from app.services.provider_settings import (
    env_speech_model,
    env_story_model,
    resolve_speech_model,
    resolve_story_model,
)


def test_env_story_model_by_provider():
    s = Settings(
        ark_model="ark-x",
        deepseek_model="ds-x",
        openai_model="oai-x",
        mock_providers=False,
    )
    assert env_story_model("doubao", s) == "ark-x"
    assert env_story_model("deepseek", s) == "ds-x"
    assert env_story_model("openai", s) == "oai-x"


def test_env_speech_model_by_provider():
    s = Settings(
        fish_audio_tts_model="s2-pro",
        elevenlabs_model_id="eleven_multilingual_v2",
        volc_tts_resource_id="seed-tts-2.0",
        aliyun_tts_model="cosyvoice-v3-flash",
        mock_providers=False,
    )
    assert env_speech_model("fishaudio", s) == "s2-pro"
    assert env_speech_model("elevenlabs", s) == "eleven_multilingual_v2"
    assert env_speech_model("volc", s) == "seed-tts-2.0"
    assert env_speech_model("aliyun", s) == "cosyvoice-v3-flash"


@pytest.mark.asyncio
async def test_resolve_story_model_prefers_override():
    s = Settings(ark_model="ark-env", mock_providers=False)
    with (
        patch(
            "app.services.provider_settings.get_runtime_overrides",
            AsyncMock(return_value={"story_model": "ark-override"}),
        ),
        patch("app.services.provider_settings.get_settings", return_value=s),
    ):
        assert await resolve_story_model("doubao") == "ark-override"


@pytest.mark.asyncio
async def test_resolve_speech_model_falls_back_env():
    s = Settings(fish_audio_tts_model="s1", mock_providers=False)
    with (
        patch(
            "app.services.provider_settings.get_runtime_overrides",
            AsyncMock(return_value={}),
        ),
        patch("app.services.provider_settings.get_settings", return_value=s),
    ):
        assert await resolve_speech_model("fishaudio") == "s1"


@pytest.mark.asyncio
async def test_resolve_speech_model_voice_beats_env():
    s = Settings(aliyun_tts_model="cosyvoice-v3-flash", mock_providers=False)
    with patch("app.services.provider_settings.get_settings", return_value=s):
        assert await resolve_speech_model("aliyun", voice_model="voice-model") == "voice-model"
        assert await resolve_speech_model("aliyun") == "cosyvoice-v3-flash"
