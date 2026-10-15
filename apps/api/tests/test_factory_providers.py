from unittest.mock import patch

from app.core.config import Settings
from app.providers.deepseek_story import DeepSeekStoryProvider
from app.providers.doubao_story import DoubaoStoryProvider
from app.providers.elevenlabs_tts import ElevenLabsTtsProvider, ElevenLabsVoiceCloneProvider
from app.providers.factory import get_clone_provider, get_story_provider, get_tts_provider
from app.providers.fish_tts import FishAudioTtsProvider, FishAudioVoiceCloneProvider
from app.providers.mock import MockStoryProvider, MockTtsProvider, MockVoiceCloneProvider
from app.providers.openai_story import OpenAIStoryProvider
from app.providers.volc_tts import VolcTtsProvider, VolcVoiceCloneProvider
from app.services.provider_settings import (
    env_speech_provider,
    env_story_provider,
    profile_defaults,
    speech_default_voice_id,
)


def test_profile_fish_defaults():
    s = Settings(provider_profile="fish", story_provider="", speech_provider="", mock_providers=False)
    assert profile_defaults(s) == ("doubao", "fishaudio")
    assert env_story_provider(s) == "doubao"
    assert env_speech_provider(s) == "fishaudio"


def test_explicit_knobs_override_profile():
    s = Settings(
        provider_profile="volc",
        story_provider="openai",
        speech_provider="fishaudio",
        mock_providers=False,
    )
    assert env_story_provider(s) == "openai"
    assert env_speech_provider(s) == "fishaudio"


def test_factory_by_name():
    s = Settings(mock_providers=False, provider_profile="fish")
    with patch("app.providers.factory.get_settings", return_value=s):
        assert isinstance(get_story_provider("doubao"), DoubaoStoryProvider)
        assert isinstance(get_story_provider("openai"), OpenAIStoryProvider)
        assert isinstance(get_story_provider("deepseek"), DeepSeekStoryProvider)
        assert isinstance(get_tts_provider("fishaudio"), FishAudioTtsProvider)
        assert isinstance(get_clone_provider("fishaudio"), FishAudioVoiceCloneProvider)
        assert isinstance(get_tts_provider("volc"), VolcTtsProvider)
        assert isinstance(get_clone_provider("volc"), VolcVoiceCloneProvider)
        assert isinstance(get_tts_provider("elevenlabs"), ElevenLabsTtsProvider)
        assert isinstance(get_clone_provider("elevenlabs"), ElevenLabsVoiceCloneProvider)
        assert isinstance(get_story_provider("mock"), MockStoryProvider)
        assert isinstance(get_tts_provider("mock"), MockTtsProvider)
        assert isinstance(get_clone_provider("mock"), MockVoiceCloneProvider)


def test_mock_providers_forces_mock():
    s = Settings(mock_providers=True, provider_profile="fish")
    with patch("app.providers.factory.get_settings", return_value=s):
        assert isinstance(get_story_provider("doubao"), MockStoryProvider)
        assert isinstance(get_tts_provider("fishaudio"), MockTtsProvider)
        assert isinstance(get_clone_provider("fishaudio"), MockVoiceCloneProvider)


def test_fish_default_voice_id_has_no_placeholder():
    s = Settings(fish_audio_default_voice_id="")
    assert speech_default_voice_id("fishaudio", s) == ""
    s2 = Settings(fish_audio_default_voice_id="  real-voice-id  ")
    assert speech_default_voice_id("fishaudio", s2) == "real-voice-id"
