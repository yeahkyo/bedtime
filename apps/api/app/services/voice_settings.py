from app.providers.base import VoiceSettings


SPEED_MAP = {"slow": 0.85, "medium": 1.0, "fast": 1.1}
TONE_MAP = {
    "gentle": {"stability": 0.65, "style": 0.05},
    "clear": {"stability": 0.75, "style": 0.0},
    "lively": {"stability": 0.45, "style": 0.25},
}


def resolve_voice_settings(
    speed_tier: str = "slow",
    tone_preset: str = "gentle",
    likeness_boost: bool = False,
) -> VoiceSettings:
    speed = SPEED_MAP.get(speed_tier, 0.85)
    tone = TONE_MAP.get(tone_preset, TONE_MAP["gentle"])
    similarity = 0.85 if likeness_boost else 0.75
    return VoiceSettings(
        speed=speed,
        stability=tone["stability"],
        style=tone["style"],
        similarity_boost=similarity,
    )
