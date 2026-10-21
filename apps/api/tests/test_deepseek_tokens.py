"""DeepSeek content + CoT budget and truncation retry policy."""

import pytest

from app.providers.deepseek_budget import (
    DeepSeekTruncatedError,
    cot_budget_for_effort,
    effort_for_stage,
    total_max_tokens,
)
from app.providers.story_pipeline import _chat_json, _is_truncated_error


def test_total_max_tokens_splits_content_and_cot():
    assert total_max_tokens(2574, thinking_on=False) == 2574
    assert total_max_tokens(2574, thinking_on=True, effort="low") == 2574 + 4096
    assert total_max_tokens(2574, thinking_on=True, effort="high") == 2574 + 12288
    assert total_max_tokens(30000, thinking_on=True, effort="max") == 32768


def test_effort_for_stage_defaults_low_and_settings_is_ceiling():
    assert effort_for_stage("draft", settings_effort="high") == "low"
    assert effort_for_stage("episode_plan", settings_effort="max") == "low"
    assert effort_for_stage("draft", settings_effort="low") == "low"
    assert cot_budget_for_effort("low") == 4096


def test_truncated_error_detected():
    err = DeepSeekTruncatedError(
        "truncated",
        stage="draft",
        finish_reason="length",
        reasoning_chars=10000,
        content_chars=100,
        max_tokens=8000,
        effort="low",
    )
    assert _is_truncated_error(err)
    assert _is_truncated_error(RuntimeError("finish_reason=length"))
    assert not _is_truncated_error(ValueError("invalid json"))


@pytest.mark.asyncio
async def test_chat_json_retries_by_disabling_thinking():
    calls: list[dict] = []

    async def chat(
        system,
        user,
        *,
        max_tokens,
        timeout,
        stage="chat",
        model=None,
        thinking=None,
        reasoning_effort=None,
    ):
        calls.append({"thinking": thinking, "max_tokens": max_tokens})
        if thinking is not False:
            raise DeepSeekTruncatedError(
                "truncated",
                stage=stage,
                finish_reason="length",
                reasoning_chars=9000,
                content_chars=50,
                max_tokens=8000,
                effort="low",
            )
        return '{"title":"ok","body":"hi"}'

    data = await _chat_json(
        chat,
        system="s",
        user="u",
        stage="draft",
        max_tokens=2000,
        timeout=10,
        retries=1,
    )
    assert data["title"] == "ok"
    assert calls[0]["thinking"] is None
    assert calls[1]["thinking"] is False
    # Must not double the content budget on first truncation retry.
    assert calls[1]["max_tokens"] <= int(2000 * 1.15) + 1
