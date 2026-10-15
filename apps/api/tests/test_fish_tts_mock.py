from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.core.config import clear_settings_cache
from app.providers.base import VoiceSettings
from app.providers.fish_tts import FishAudioTtsProvider, FishAudioVoiceCloneProvider


@pytest.mark.asyncio
async def test_fish_tts_synthesize(monkeypatch):
    clear_settings_cache()
    monkeypatch.setenv("FISH_AUDIO_API_KEY", "test-key")
    monkeypatch.setenv("FISH_AUDIO_TTS_MODEL", "s2-pro")
    clear_settings_cache()

    mock_response = MagicMock()
    mock_response.status_code = 200

    async def _aiter_bytes():
        yield b"ID3fake-mp3"

    mock_response.aiter_bytes = _aiter_bytes

    mock_stream = MagicMock()
    mock_stream.__aenter__ = AsyncMock(return_value=mock_response)
    mock_stream.__aexit__ = AsyncMock(return_value=False)

    mock_client = MagicMock()
    mock_client.stream = MagicMock(return_value=mock_stream)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.providers.fish_tts.httpx.AsyncClient", return_value=mock_client):
        tts = FishAudioTtsProvider()
        audio = await tts.synthesize("晚安", "voice-1", VoiceSettings(speed=0.9))

    assert audio == b"ID3fake-mp3"
    assert mock_client.stream.called
    clear_settings_cache()


@pytest.mark.asyncio
async def test_fish_clone_returns_id(monkeypatch):
    clear_settings_cache()
    monkeypatch.setenv("FISH_AUDIO_API_KEY", "test-key")
    clear_settings_cache()

    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json = MagicMock(return_value={"_id": "model-abc", "state": "trained"})
    mock_resp.text = ""

    mock_client = MagicMock()
    mock_client.post = AsyncMock(return_value=mock_resp)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)

    with patch("app.providers.fish_tts.httpx.AsyncClient", return_value=mock_client):
        clone = FishAudioVoiceCloneProvider()
        vid = await clone.clone("爸妈", b"x" * 2000, "sample.wav", "zh")

    assert vid == "model-abc"
    clear_settings_cache()
