"""Aliyun CosyVoice TTS helpers + factory wiring."""

from unittest.mock import AsyncMock, patch

import pytest

from app.core.config import Settings
from app.providers.aliyun_tts import (
    AliyunTtsProvider,
    AliyunVoiceCloneProvider,
    _parse_sse_json_events,
    _safe_prefix,
    _tts_url,
    _workspace_base,
)
from app.providers.base import VoiceSettings
from app.providers.factory import get_clone_provider, get_tts_provider
from app.services.provider_settings import (
    env_speech_model,
    provider_configured,
    speech_default_voice_id,
)


def test_safe_prefix():
    assert _safe_prefix("豆豆 Voice!") == "voice"
    assert _safe_prefix("MyVoice123") == "myvoice123"
    assert len(_safe_prefix("abcdefghijklmnop")) <= 10


def test_parse_sse_json_events():
    buf = (
        'data: {"output":{"audio":{"data":"YQ=="}}}\n\n'
        'data: {"output":{"finish_reason":"stop"}}\n\n'
        "data: partial"
    )
    events, rem = _parse_sse_json_events(buf)
    assert len(events) == 2
    assert events[0]["output"]["audio"]["data"] == "YQ=="
    assert rem.startswith("data: partial")


def test_workspace_base_and_tts_url():
    s = Settings(
        aliyun_tts_workspace_id="ws-demo",
        aliyun_tts_region="cn-beijing",
        aliyun_tts_base_url="",
        mock_providers=False,
    )
    with patch("app.providers.aliyun_tts.get_settings", return_value=s):
        assert _workspace_base() == "https://ws-demo.cn-beijing.maas.aliyuncs.com/api/v1"
        assert _tts_url().endswith("/services/audio/tts/SpeechSynthesizer")


def test_legacy_dashscope_host_without_workspace():
    s = Settings(aliyun_tts_workspace_id="", aliyun_tts_base_url="", mock_providers=False)
    with patch("app.providers.aliyun_tts.get_settings", return_value=s):
        assert _workspace_base() == "https://dashscope.aliyuncs.com/api/v1"


def test_provider_settings_aliyun():
    s = Settings(
        aliyun_dashscope_api_key="sk-x",
        aliyun_tts_model="cosyvoice-v3-plus",
        aliyun_tts_default_voice="longanyang",
        mock_providers=False,
    )
    assert provider_configured("speech", "aliyun", s) is True
    assert env_speech_model("aliyun", s) == "cosyvoice-v3-plus"
    assert speech_default_voice_id("aliyun", s) == "longanyang"


def test_factory_aliyun():
    s = Settings(mock_providers=False, provider_profile="aliyun")
    with patch("app.providers.factory.get_settings", return_value=s):
        assert isinstance(get_tts_provider("aliyun"), AliyunTtsProvider)
        assert isinstance(get_clone_provider("aliyun"), AliyunVoiceCloneProvider)
        assert isinstance(get_tts_provider("dashscope"), AliyunTtsProvider)


@pytest.mark.asyncio
async def test_synthesize_via_url_fallback():
    s = Settings(
        aliyun_dashscope_api_key="sk-test",
        aliyun_tts_workspace_id="ws",
        aliyun_tts_model="cosyvoice-v3-flash",
        mock_providers=False,
    )
    provider = AliyunTtsProvider()
    fake_audio = b"ID3fake-mp3"

    class _Resp:
        status_code = 200
        text = ""

        def json(self):
            return {"output": {"audio": {"url": "https://example.com/a.mp3"}}}

        @property
        def content(self):
            return fake_audio

    class _Client:
        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return None

        async def post(self, *args, **kwargs):
            return _Resp()

        async def get(self, *args, **kwargs):
            return _Resp()

    with (
        patch("app.providers.aliyun_tts.get_settings", return_value=s),
        patch(
            "app.services.provider_settings.resolve_speech_model",
            AsyncMock(return_value="cosyvoice-v3-flash"),
        ),
        patch("app.providers.aliyun_tts.httpx.AsyncClient", return_value=_Client()),
    ):
        out = await provider._synthesize_via_url(
            "你好",
            "longanyang",
            VoiceSettings(speed=0.9),
        )
    assert out == fake_audio
