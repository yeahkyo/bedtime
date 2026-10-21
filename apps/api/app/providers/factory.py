from app.core.config import get_settings
from app.providers.aliyun_tts import AliyunTtsProvider, AliyunVoiceCloneProvider
from app.providers.base import StoryProvider, TtsProvider, VoiceCloneProvider
from app.providers.deepseek_story import DeepSeekStoryProvider
from app.providers.doubao_story import DoubaoStoryProvider
from app.providers.elevenlabs_tts import ElevenLabsTtsProvider, ElevenLabsVoiceCloneProvider
from app.providers.fish_tts import FishAudioTtsProvider, FishAudioVoiceCloneProvider
from app.providers.mock import MockStoryProvider, MockTtsProvider, MockVoiceCloneProvider
from app.providers.openai_story import OpenAIStoryProvider
from app.providers.volc_tts import VolcTtsProvider, VolcVoiceCloneProvider
from app.services.provider_settings import first_configured_speech_provider, env_story_provider


def _normalize(name: str | None) -> str | None:
    if name is None:
        return None
    cleaned = name.strip().lower()
    return cleaned or None


def get_story_provider(name: str | None = None) -> StoryProvider:
    settings = get_settings()
    resolved = _normalize(name) or env_story_provider(settings)
    if settings.mock_providers or resolved == "mock":
        return MockStoryProvider()
    if resolved in ("doubao", "volc", "ark"):
        return DoubaoStoryProvider()
    if resolved == "openai":
        return OpenAIStoryProvider()
    if resolved == "deepseek":
        return DeepSeekStoryProvider()
    raise RuntimeError(f"Unknown story provider: {resolved}")


def get_tts_provider(name: str | None = None) -> TtsProvider:
    settings = get_settings()
    resolved = _normalize(name) or first_configured_speech_provider(settings)
    if settings.mock_providers or resolved == "mock":
        return MockTtsProvider()
    if resolved in ("volc", "doubao", "ark"):
        return VolcTtsProvider()
    if resolved == "elevenlabs":
        return ElevenLabsTtsProvider()
    if resolved == "fishaudio":
        return FishAudioTtsProvider()
    if resolved in ("aliyun", "dashscope", "cosyvoice"):
        return AliyunTtsProvider()
    raise RuntimeError(f"Unknown speech/TTS provider: {resolved}")


def get_clone_provider(name: str | None = None) -> VoiceCloneProvider:
    settings = get_settings()
    resolved = _normalize(name) or first_configured_speech_provider(settings)
    if settings.mock_providers or resolved == "mock":
        return MockVoiceCloneProvider()
    if resolved in ("volc", "doubao", "ark"):
        return VolcVoiceCloneProvider()
    if resolved == "elevenlabs":
        return ElevenLabsVoiceCloneProvider()
    if resolved == "fishaudio":
        return FishAudioVoiceCloneProvider()
    if resolved in ("aliyun", "dashscope", "cosyvoice"):
        return AliyunVoiceCloneProvider()
    raise RuntimeError(f"Unknown speech/clone provider: {resolved}")
