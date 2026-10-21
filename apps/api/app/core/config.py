from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_JWT_SECRET = "dev-change-me-in-production"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    env: str = "dev"
    dev_auth_bypass: bool = True
    mock_providers: bool = True

    database_url: str = "mysql+asyncmy://bedtime:bedtime@127.0.0.1:3307/bedtime"
    redis_url: str = "redis://127.0.0.1:6379/0"

    jwt_secret: str = DEFAULT_JWT_SECRET
    jwt_algorithm: str = "HS256"
    jwt_expire_days: int = 30

    # Comma-separated browser origins for non-dev CORS (empty = no browser CORS).
    cors_origins: str = ""
    # Header X-Retention-Admin-Token must match for POST /v1/account/retention/run outside is_dev.
    retention_admin_token: str | None = None

    # Admin UI bootstrap (Bandage-style). Empty password disables login.
    admin_bootstrap_username: str = "admin"
    admin_bootstrap_password: str | None = None
    admin_jwt_expire_hours: int = 12

    s3_endpoint_url: str | None = "http://127.0.0.1:9000"
    s3_access_key: str = "minioadmin"
    s3_secret_key: str = "minioadmin"
    s3_bucket: str = "bedtime"
    s3_region: str = "auto"
    s3_public_base_url: str | None = None
    storage_backend: str = "s3"  # s3 | local

    # Compat preset: volc | openai | fish (doubao+fishaudio). Overridden by story/speech knobs.
    provider_profile: str = "fish"

    # Story knob (empty = derive from provider_profile). Speech is per-Voice.
    story_provider: str = ""
    # Deprecated / unused: kept so old .env files still load.
    speech_provider: str = ""
    # When True, skip TTS after LLM (text-only ready). Prefer env STORY_SKIP_TTS=1 temporarily.
    story_skip_tts: bool = False

    openai_api_key: str | None = None
    openai_model: str = "gpt-4o-mini"

    deepseek_api_key: str | None = None
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_model: str = "deepseek-flash"
    # Story chat CoT: enabled improves quality for some models; costs latency/tokens.
    deepseek_thinking: bool = True
    # Ceiling for story stages (outline/plan/draft default low; cannot raise above stage).
    # low | medium | high | max. Ignored when thinking is off.
    deepseek_reasoning_effort: str = "low"

    ark_api_key: str | None = None
    ark_base_url: str = "https://ark.cn-beijing.volces.com/api/v3"
    ark_model: str = "doubao-seed-1.6-250615"

    # Doubao Voice / openspeech; falls back to ark_api_key if empty
    volc_speech_api_key: str | None = None
    volc_tts_resource_id: str = "seed-tts-2.0"
    volc_icl_resource_id: str = "seed-icl-2.0"
    volc_default_speaker: str = "zh_female_vv_uranus_bigtts"
    # Opt-in: send SSML <break>/<prosody> for non-clone voices (off for seed-tts-2.0 by default).
    volc_tts_enable_ssml: bool = False

    elevenlabs_api_key: str | None = None
    elevenlabs_default_voice_id: str = "21m00Tcm4TlvDq8ikWAM"
    elevenlabs_model_id: str = "eleven_multilingual_v2"

    fish_audio_api_key: str | None = None
    fish_audio_default_voice_id: str = ""
    fish_audio_tts_model: str = "s2-pro"
    fish_audio_base_url: str = "https://api.fish.audio"

    # Aliyun Model Studio / DashScope CosyVoice TTS (+ voice enrollment)
    # Prefer ALIYUN_DASHSCOPE_API_KEY; DASHSCOPE_API_KEY also accepted.
    aliyun_dashscope_api_key: str | None = None
    dashscope_api_key: str | None = None
    aliyun_tts_workspace_id: str = ""
    aliyun_tts_region: str = "cn-beijing"  # cn-beijing | ap-southeast-1
    aliyun_tts_model: str = "cosyvoice-v3-flash"
    aliyun_tts_default_voice: str = "longanyang"
    # Optional override: api/v1 root or full SpeechSynthesizer URL.
    aliyun_tts_base_url: str = ""

    story_retention_months: int = 24
    raw_voice_retention_hours: int = 24
    monthly_story_quota: int = 30
    monthly_clone_quota: int = 3

    @property
    def is_dev(self) -> bool:
        return self.env == "dev"

    def cors_origin_list(self) -> list[str]:
        if not self.cors_origins.strip():
            return []
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


class SettingsValidationError(RuntimeError):
    """Raised when non-dev settings are unsafe to serve traffic."""


def validate_settings_for_runtime(settings: Settings | None = None) -> None:
    """Refuse to start with unsafe defaults outside env=dev."""
    s = settings or get_settings()
    if s.is_dev:
        return
    errors: list[str] = []
    if s.jwt_secret == DEFAULT_JWT_SECRET or not s.jwt_secret.strip():
        errors.append("JWT_SECRET must be set to a non-default value when ENV is not dev")
    if s.dev_auth_bypass:
        errors.append("DEV_AUTH_BYPASS must be false when ENV is not dev")
    # local + anonymous /media is dev-only; non-dev with local leaves audio URLs broken.
    if s.storage_backend.strip().lower() != "s3":
        errors.append("STORAGE_BACKEND must be s3 when ENV is not dev")
    if not (s.retention_admin_token or "").strip():
        errors.append("RETENTION_ADMIN_TOKEN must be set when ENV is not dev")
    if not (s.admin_bootstrap_password or "").strip():
        errors.append("ADMIN_BOOTSTRAP_PASSWORD must be set when ENV is not dev")
    if errors:
        raise SettingsValidationError("; ".join(errors))


@lru_cache
def get_settings() -> Settings:
    return Settings()


def clear_settings_cache() -> None:
    get_settings.cache_clear()
