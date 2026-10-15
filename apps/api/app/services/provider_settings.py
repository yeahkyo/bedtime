"""Resolve story/speech provider names: runtime override → env knobs → profile preset."""

from __future__ import annotations

import json
from typing import Any

from app.core.config import Settings, get_settings
from app.core.redis_client import get_redis

RUNTIME_SETTINGS_KEY = "bedtime:runtime_settings"

STORY_PROVIDERS = ("doubao", "openai", "deepseek", "mock")
SPEECH_PROVIDERS = ("fishaudio", "volc", "elevenlabs", "mock")

# provider_profile → (story_provider, speech_provider)
PROFILE_PRESETS: dict[str, tuple[str, str]] = {
    "volc": ("doubao", "volc"),
    "doubao": ("doubao", "volc"),
    "ark": ("doubao", "volc"),
    "openai": ("openai", "elevenlabs"),
    "deepseek": ("deepseek", "fishaudio"),
    "fish": ("doubao", "fishaudio"),
    "fishaudio": ("doubao", "fishaudio"),
}


def profile_defaults(settings: Settings | None = None) -> tuple[str, str]:
    s = settings or get_settings()
    profile = (s.provider_profile or "fish").strip().lower()
    return PROFILE_PRESETS.get(profile, ("doubao", "fishaudio"))


def env_story_provider(settings: Settings | None = None) -> str:
    s = settings or get_settings()
    if s.mock_providers:
        return "mock"
    explicit = (s.story_provider or "").strip().lower()
    if explicit:
        return explicit
    return profile_defaults(s)[0]


def env_speech_provider(settings: Settings | None = None) -> str:
    s = settings or get_settings()
    if s.mock_providers:
        return "mock"
    explicit = (s.speech_provider or "").strip().lower()
    if explicit:
        return explicit
    return profile_defaults(s)[1]


async def get_runtime_overrides() -> dict[str, str]:
    try:
        redis = await get_redis()
        raw = await redis.get(RUNTIME_SETTINGS_KEY)
    except Exception:
        return {}
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    if not isinstance(data, dict):
        return {}
    out: dict[str, str] = {}
    for key in ("story_provider", "speech_provider"):
        val = data.get(key)
        if isinstance(val, str) and val.strip():
            out[key] = val.strip().lower()
    return out


async def set_runtime_overrides(
    *,
    story_provider: str | None = None,
    speech_provider: str | None = None,
) -> dict[str, str]:
    current = await get_runtime_overrides()
    if story_provider is not None:
        name = story_provider.strip().lower()
        if name not in STORY_PROVIDERS:
            raise ValueError(f"Invalid story_provider: {story_provider}")
        current["story_provider"] = name
    if speech_provider is not None:
        name = speech_provider.strip().lower()
        if name not in SPEECH_PROVIDERS:
            raise ValueError(f"Invalid speech_provider: {speech_provider}")
        current["speech_provider"] = name
    redis = await get_redis()
    await redis.set(RUNTIME_SETTINGS_KEY, json.dumps(current))
    return current


async def resolve_story_provider_name() -> str:
    overrides = await get_runtime_overrides()
    if "story_provider" in overrides:
        return overrides["story_provider"]
    return env_story_provider()


async def resolve_speech_provider_name() -> str:
    overrides = await get_runtime_overrides()
    if "speech_provider" in overrides:
        return overrides["speech_provider"]
    return env_speech_provider()


def speech_default_voice_id(speech_provider: str, settings: Settings | None = None) -> str:
    s = settings or get_settings()
    name = speech_provider.strip().lower()
    if name == "volc":
        return s.volc_default_speaker
    if name == "elevenlabs":
        return s.elevenlabs_default_voice_id
    if name == "fishaudio":
        # Empty means unset — never invent a placeholder Fish will reject.
        return (s.fish_audio_default_voice_id or "").strip()
    if name == "mock":
        return "mock_system_voice"
    return s.volc_default_speaker


def provider_configured(kind: str, name: str, settings: Settings | None = None) -> bool:
    """Whether keys exist so this provider can run (mock always true)."""
    s = settings or get_settings()
    n = name.strip().lower()
    if n == "mock" or s.mock_providers:
        return True
    if kind == "story":
        if n == "doubao":
            return bool(s.ark_api_key)
        if n == "openai":
            return bool(s.openai_api_key)
        if n == "deepseek":
            return bool(s.deepseek_api_key)
        return False
    if kind == "speech":
        if n == "volc":
            return bool(s.volc_speech_api_key or s.ark_api_key)
        if n == "elevenlabs":
            return bool(s.elevenlabs_api_key)
        if n == "fishaudio":
            return bool(s.fish_audio_api_key)
        return False
    return False


def list_available_providers(settings: Settings | None = None) -> dict[str, Any]:
    s = settings or get_settings()
    return {
        "story_providers": [
            {"id": p, "configured": provider_configured("story", p, s)} for p in STORY_PROVIDERS
        ],
        "speech_providers": [
            {"id": p, "configured": provider_configured("speech", p, s)} for p in SPEECH_PROVIDERS
        ],
    }
