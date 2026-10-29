from datetime import date

from pydantic import BaseModel, Field, field_validator


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class DevLoginRequest(BaseModel):
    display_name: str = "Dev Parent"
    preferred_language: str = "zh"


class AppleLoginRequest(BaseModel):
    identity_token: str
    display_name: str | None = None
    preferred_language: str = "zh"


class RegisterRequest(BaseModel):
    invite_code: str = Field(min_length=4, max_length=32)
    phone: str = Field(min_length=8, max_length=20)
    password: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=128)
    preferred_language: str = "zh"


class LoginRequest(BaseModel):
    phone: str = Field(min_length=8, max_length=20)
    password: str = Field(min_length=8, max_length=128)


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=16, max_length=256)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=16, max_length=256)


class ChildCreate(BaseModel):
    nickname: str = Field(min_length=1, max_length=64)
    birth_date: date | None = None
    # Deprecated: accepted for old clients; ignored when birth_date is set.
    age_band: str | None = None
    gender: str = "unspecified"
    intro: str | None = Field(default=None, max_length=2000)
    # Story preferences (tags); persisted in Child.interests_json column.
    prefer: list[str] = []

    @field_validator("gender")
    @classmethod
    def _gender(cls, v: str) -> str:
        from app.services.child_profile import normalize_gender

        return normalize_gender(v)


class ChildUpdate(BaseModel):
    nickname: str | None = Field(default=None, min_length=1, max_length=64)
    birth_date: date | None = None
    age_band: str | None = None  # deprecated
    gender: str | None = None
    intro: str | None = Field(default=None, max_length=2000)
    prefer: list[str] | None = None

    @field_validator("gender")
    @classmethod
    def _gender(cls, v: str | None) -> str | None:
        if v is None:
            return None
        from app.services.child_profile import normalize_gender

        return normalize_gender(v)


class ChildOut(BaseModel):
    id: int
    nickname: str
    birth_date: date | None = None
    age_band: str  # derived from birth_date for story dials
    gender: str = "unspecified"
    intro: str | None = None
    prefer: list[str] = []

    model_config = {"from_attributes": True}


class CharacterCreate(BaseModel):
    """Client may only create person | toy (listener twin is auto-provisioned)."""

    kind: str = Field(min_length=1, max_length=16)
    name: str = Field(min_length=1, max_length=64)
    related_child_id: int
    relation: str | None = Field(default=None, max_length=64)
    note: str | None = Field(default=None, max_length=200)


class CharacterUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=64)
    relation: str | None = Field(default=None, max_length=64)
    note: str | None = Field(default=None, max_length=200)
    enabled: bool | None = None
    related_child_id: int | None = None


class CharacterOut(BaseModel):
    id: int
    kind: str
    name: str
    related_child_id: int | None = None
    relation: str | None = None
    note: str | None = None
    listener_child_id: int | None = None
    enabled: bool = True

    model_config = {"from_attributes": True}


class VoicePrefsUpdate(BaseModel):
    speed_tier: str = "medium"
    tone_preset: str = "gentle"
    likeness_boost: bool = False
    default_voice_id: int | None = None


class VoiceOut(BaseModel):
    id: int
    name: str
    kind: str
    language: str
    provider: str = "fishaudio"
    provider_voice_id: str
    speech_model: str | None = None
    speed_tier: str = "medium"
    speed: float = 1.0
    enabled: bool = True
    description: str | None = None
    sort_order: int = 0
    # Persisted sample from admin; null until generated.
    preview_audio_url: str | None = None

    model_config = {"from_attributes": True}


class VoiceUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    # Optional; omit to leave unchanged on client PATCH that only renames.
    speech_model: str | None = None
    provider: str | None = None
    provider_voice_id: str | None = None


class AudienceItem(BaseModel):
    """Tonight's listeners for the story agent (name/age/gender/desc/prefer)."""

    name: str = Field(min_length=1, max_length=64)
    age: int | None = Field(default=None, ge=0, le=18)
    gender: str | None = Field(default=None, max_length=32)
    desc: str | None = Field(default=None, max_length=2000)
    prefer: str | None = Field(default=None, max_length=2000)


class StoryCreate(BaseModel):
    child_id: int
    # Client: seed ≤40 / plot ≤280 (same for any input language).
    theme: str = Field(default="a gentle forest adventure", max_length=280)
    # seed = one-line inspiration; plot = follow user's written synopsis.
    theme_mode: str = Field(default="seed", pattern="^(seed|plot)$")
    # user = typed; hint = client filled tonight's spark example because field was empty.
    theme_source: str = Field(default="user", pattern="^(user|hint)$")
    # When theme_source=hint, optional catalog id so we can suppress that spark later.
    theme_spark_id: int | None = Field(default=None, ge=1)
    language: str = "zh"
    duration_minutes: int = Field(default=5, ge=2, le=12)
    voice_id: int | None = None
    # Tonight listeners (primary + companions); age/gender live here, not at root.
    audiences: list[AudienceItem] = []
    # Tonight roster picks from /v1/characters.
    character_ids: list[int] = []
    # Style dials still exposed in the create UI.
    wonder: str = "soft"  # everyday | soft | fantasy
    dialogue: str = "some"  # low | some | more


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
    core: str | None = None
    story_provider: str | None = None
    story_model: str | None = None
    speech_provider: str | None = None
    speech_model: str | None = None

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
