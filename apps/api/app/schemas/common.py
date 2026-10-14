from pydantic import BaseModel, Field


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class DevLoginRequest(BaseModel):
    display_name: str = "Dev Parent"
    preferred_language: str = "zh"


class AppleLoginRequest(BaseModel):
    identity_token: str
    display_name: str | None = None
    preferred_language: str = "zh"


class ChildCreate(BaseModel):
    nickname: str = Field(min_length=1, max_length=64)
    age_band: str = "3-5"
    interests: list[str] = []


class ChildUpdate(BaseModel):
    nickname: str | None = Field(default=None, min_length=1, max_length=64)
    age_band: str | None = None
    interests: list[str] | None = None


class ChildOut(BaseModel):
    id: int
    nickname: str
    age_band: str
    interests: list[str] = []

    model_config = {"from_attributes": True}


class VoicePrefsUpdate(BaseModel):
    speed_tier: str = "slow"
    tone_preset: str = "gentle"
    likeness_boost: bool = False
    default_voice_id: int | None = None


class VoiceOut(BaseModel):
    id: int
    name: str
    kind: str
    language: str
    provider_voice_id: str

    model_config = {"from_attributes": True}


class StoryCreate(BaseModel):
    child_id: int
    theme: str = "a gentle forest adventure"
    language: str = "zh"
    duration_minutes: int = Field(default=5, ge=2, le=12)
    voice_id: int | None = None
    values: list[str] = []
    soft_series_mode: bool = False
    recap: str | None = None
    # Continue an existing soft series (omit to start a new one when soft_series_mode).
    series_id: int | None = None
    episode_count: int = Field(default=4, ge=2, le=8)
    source: str = "manual"
    memory_ids: list[int] = []
    # Personalization tags: people / toys / places / events (also for future photo extract)
    keywords: list[str] = []
    # Optional soft developmental focus id (e.g. tiny_brave); auto-picked by age if omitted
    development_focus: str | None = None
    # auto | protagonist | supporting | absent
    child_cast_role: str = "auto"
    # Style dials
    plot_drive: str = "light"  # mood | light | arc
    imagery: str = "balanced"  # sparse | balanced | rich
    wonder: str = "soft"  # everyday | soft | fantasy
    wind_down: str = "gentle"  # deep | gentle | playful
    dialogue: str = "some"  # low | some | more
    lead_in: str = "soft"  # none | soft | curious


class StoryOut(BaseModel):
    id: int
    title: str
    language: str
    theme: str | None
    body: str
    status: str
    source: str
    soft_hook: str | None = None
    audio_url: str | None = None
    duration_minutes: int
    series_id: int | None = None
    episode_no: int | None = None
    child_id: int | None = None
    progress: str | None = None
    error_message: str | None = None
    voice_name: str | None = None
    development_focus_label: str | None = None

    model_config = {"from_attributes": True}


class QuotaOut(BaseModel):
    month: str
    story_used: int
    story_limit: int
    clone_used: int
    clone_limit: int


class UserOut(BaseModel):
    id: int
    display_name: str | None = None
    preferred_language: str = "zh"

    model_config = {"from_attributes": True}


class CloneConsent(BaseModel):
    consent: bool
    name: str = "My voice"
    language: str = "zh"
