"""DeepSeek max_tokens = visible content budget + CoT budget (shared API cap)."""

from __future__ import annotations

# API max_tokens covers reasoning_content + content. Keep a hard ceiling.
MAX_TOKENS_CAP = 32768

# Tokens reserved for chain-of-thought at each effort (not multiplied from content).
COT_BUDGET: dict[str, int] = {
    "low": 4096,
    "medium": 8192,
    "high": 12288,
    "max": 20480,
}

# Story stages: prefer short CoT; settings effort is a ceiling (cannot raise above stage).
_STAGE_EFFORT: dict[str, str] = {
    "series_outline": "low",
    "outline": "low",
    "episode_plan": "low",
    "draft": "low",
}

_EFFORT_RANK = {"low": 0, "medium": 1, "high": 2, "max": 3}


def normalize_effort(raw: str | None) -> str:
    e = (raw or "low").strip().lower()
    if e == "medium":
        return "medium"
    if e in _EFFORT_RANK:
        return e
    return "low"


def _min_effort(a: str, b: str) -> str:
    ra, rb = _EFFORT_RANK[normalize_effort(a)], _EFFORT_RANK[normalize_effort(b)]
    return a if ra <= rb else b


def effort_for_stage(stage: str, *, settings_effort: str | None = None) -> str:
    """Stage default, capped by settings effort (settings cannot force higher than stage)."""
    key = (stage or "chat").strip().lower()
    stage_e = _STAGE_EFFORT.get(key, "low")
    if settings_effort is None:
        return stage_e
    return _min_effort(stage_e, settings_effort)


def cot_budget_for_effort(effort: str | None) -> int:
    return COT_BUDGET[normalize_effort(effort)]


def total_max_tokens(
    content_budget: int,
    *,
    thinking_on: bool,
    effort: str | None = "low",
) -> int:
    """content_budget = visible JSON size; add CoT reserve when thinking is on."""
    content = max(1, int(content_budget or 1))
    if not thinking_on:
        return min(MAX_TOKENS_CAP, content)
    return min(MAX_TOKENS_CAP, content + cot_budget_for_effort(effort))


class DeepSeekTruncatedError(RuntimeError):
    """finish_reason=length or empty content after thinking — prefer cheaper retry."""

    def __init__(
        self,
        message: str,
        *,
        stage: str,
        finish_reason: str | None,
        reasoning_chars: int,
        content_chars: int,
        max_tokens: int,
        effort: str | None,
    ) -> None:
        super().__init__(message)
        self.stage = stage
        self.finish_reason = finish_reason
        self.reasoning_chars = reasoning_chars
        self.content_chars = content_chars
        self.max_tokens = max_tokens
        self.effort = effort
