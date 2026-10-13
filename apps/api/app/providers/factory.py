from app.core.config import get_settings
from app.providers.base import StoryProvider, TtsProvider, VoiceCloneProvider
from app.providers.doubao_story import DoubaoStoryProvider
from app.providers.elevenlabs_tts import ElevenLabsTtsProvider, ElevenLabsVoiceCloneProvider
from app.providers.mock import MockStoryProvider, MockTtsProvider, MockVoiceCloneProvider
from app.providers.openai_story import OpenAIStoryProvider
from app.providers.volc_tts import VolcTtsProvider, VolcVoiceCloneProvider


def get_story_provider() -> StoryProvider:
    settings = get_settings()
    if settings.mock_providers:
        return MockStoryProvider()
    profile = settings.provider_profile.lower()
    if profile in ("volc", "doubao", "ark"):
        return DoubaoStoryProvider()
    return OpenAIStoryProvider()


def get_tts_provider() -> TtsProvider:
    settings = get_settings()
    if settings.mock_providers:
        return MockTtsProvider()
    profile = settings.provider_profile.lower()
    if profile in ("volc", "doubao", "ark"):
        return VolcTtsProvider()
    return ElevenLabsTtsProvider()


def get_clone_provider() -> VoiceCloneProvider:
    settings = get_settings()
    if settings.mock_providers:
        return MockVoiceCloneProvider()
    profile = settings.provider_profile.lower()
    if profile in ("volc", "doubao", "ark"):
        return VolcVoiceCloneProvider()
    return ElevenLabsVoiceCloneProvider()
