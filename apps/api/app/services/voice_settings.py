from __future__ import annotations

from typing import TYPE_CHECKING

from app.providers.base import VoiceSettings

if TYPE_CHECKING:
    from app.models.voice import Voice


SPEED_MAP = {"slow": 0.85, "medium": 1.0, "fast": 1.1}
SPEED_TIERS = frozenset(SPEED_MAP)
SPEED_MIN = 0.5
SPEED_MAX = 2.0
TONE_MAP = {
    "gentle": {"stability": 0.65, "style": 0.05},
    "clear": {"stability": 0.75, "style": 0.0},
    "lively": {"stability": 0.45, "style": 0.25},
}


def normalize_speed_tier(speed_tier: str | None, *, default: str = "medium") -> str:
    tier = (speed_tier or "").strip().lower()
    if tier in SPEED_MAP:
        return tier
    return default if default in SPEED_MAP else "medium"


def clamp_speed(value: float | None, *, default: float = 1.0) -> float:
    try:
        v = float(value) if value is not None else default
    except (TypeError, ValueError):
        v = default
    if v != v:  # NaN
        v = default
    return max(SPEED_MIN, min(SPEED_MAX, v))


def speed_for_tier(speed_tier: str | None, *, default: str = "medium") -> float:
    return SPEED_MAP[normalize_speed_tier(speed_tier, default=default)]


def tier_for_speed(speed: float) -> str:
    """Best-effort legacy label for rows that still expose speed_tier."""
    s = clamp_speed(speed)
    if s <= 0.9:
        return "slow"
    if s >= 1.05:
        return "fast"
    return "medium"


def resolve_voice_settings(
    speed_tier: str = "medium",
    tone_preset: str = "gentle",
    likeness_boost: bool = False,
    *,
    speed: float | None = None,
) -> VoiceSettings:
    resolved = clamp_speed(speed) if speed is not None else speed_for_tier(speed_tier)
    tone = TONE_MAP.get(tone_preset, TONE_MAP["gentle"])
    similarity = 0.85 if likeness_boost else 0.75
    return VoiceSettings(
        speed=resolved,
        stability=tone["stability"],
        style=tone["style"],
        similarity_boost=similarity,
    )


def apply_voice_speed(settings: VoiceSettings, voice: Voice | None) -> VoiceSettings:
    """Prefer per-voice catalog speed (shared for all users) over child prefs."""
    if voice is None:
        return settings
    raw = getattr(voice, "speed", None)
    if raw is not None:
        try:
            return VoiceSettings(
                speed=clamp_speed(float(raw)),
                stability=settings.stability,
                style=settings.style,
                similarity_boost=settings.similarity_boost,
            )
        except (TypeError, ValueError):
            pass
    tier = (voice.speed_tier or "").strip().lower()
    if tier not in SPEED_MAP:
        return settings
    return VoiceSettings(
        speed=SPEED_MAP[tier],
        stability=settings.stability,
        style=settings.style,
        similarity_boost=settings.similarity_boost,
    )
