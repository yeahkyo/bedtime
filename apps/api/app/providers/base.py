"""Provider interfaces — swap OpenAI/ElevenLabs for CN or Runpod without changing routes."""

from abc import ABC, abstractmethod
from collections.abc import AsyncIterator, Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any

ProgressCallback = Callable[[str], Awaitable[None]]


@dataclass
class StoryRequest:
    child_nickname: str
    age_band: str
    language: str
    theme: str
    duration_minutes: int
    values: list[str] | None = None
    interests: list[str] | None = None
    # Recent people / things / events (manual now; photo-extracted later).
    keywords: list[str] | None = None
    require_emotional_closure: bool = True
    forbid_hard_cliffhanger: bool = True
    recap: str | None = None
    soft_series_mode: bool = False
    # Soft developmental focus for tonight (id + human instruction); optional.
    development_focus: str | None = None
    development_focus_label: str | None = None
    # auto | protagonist | supporting | absent
    child_cast_role: str = "auto"
    # Style dials (see story_prompt.STYLE_DIALS)
    plot_drive: str = "light"  # mood | light | arc
    imagery: str = "balanced"  # sparse | balanced | rich
    wonder: str = "soft"  # everyday | soft | fantasy
    wind_down: str = "gentle"  # deep | gentle | playful
    dialogue: str = "some"  # low | some | more
    lead_in: str = "soft"  # none | soft | curious
    # Soft series (outline → episode plan → draft)
    episode_count: int = 4
    episode_no: int = 1
    # When set, skip outline LLM and use this for episode N.
    series_outline: dict[str, Any] | None = None
    # True → provider must generate a new series outline before episode plan.
    need_series_outline: bool = False


@dataclass
class StoryResult:
    title: str
    body: str
    soft_hook: str | None = None
    series_outline: dict[str, Any] | None = None
    series_title: str | None = None
    episode_no: int | None = None
    episode_plan: dict[str, Any] | None = field(default=None)


@dataclass
class VoiceSettings:
    speed: float = 0.85
    stability: float = 0.65
    style: float = 0.05
    similarity_boost: float = 0.75


class StoryProvider(ABC):
    @abstractmethod
    async def generate(
        self,
        request: StoryRequest,
        on_progress: ProgressCallback | None = None,
    ) -> StoryResult:
        raise NotImplementedError

    @abstractmethod
    async def generate_stream(self, request: StoryRequest) -> AsyncIterator[str]:
        raise NotImplementedError
        yield  # pragma: no cover


class TtsProvider(ABC):
    @abstractmethod
    async def synthesize(
        self,
        text: str,
        voice_id: str,
        settings: VoiceSettings,
        *,
        speech_rate_delta: int = 0,
        loudness_rate: int = 0,
        ssml: str | None = None,
    ) -> bytes:
        raise NotImplementedError

    @abstractmethod
    async def synthesize_stream(
        self,
        text: str,
        voice_id: str,
        settings: VoiceSettings,
        *,
        speech_rate_delta: int = 0,
        loudness_rate: int = 0,
        ssml: str | None = None,
    ) -> AsyncIterator[bytes]:
        raise NotImplementedError
        yield  # pragma: no cover


class VoiceCloneProvider(ABC):
    @abstractmethod
    async def clone(self, name: str, audio_bytes: bytes, filename: str, language: str) -> str:
        """Return provider voice id."""
        raise NotImplementedError

    @abstractmethod
    async def delete(self, provider_voice_id: str) -> None:
        raise NotImplementedError
