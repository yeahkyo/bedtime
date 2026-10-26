"""LLM model registry + instance-binding routing resolver."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.services.llm_routing import (
    ResolveContext,
    draft_model_from_metrics,
    match_rule,
    resolve_llm_choice,
)


def test_match_rule_duration_bounds():
    assert match_rule({"duration_minutes_max": 5}, duration_minutes=5) is True
    assert match_rule({"duration_minutes_max": 5}, duration_minutes=6) is False
    assert match_rule({"duration_minutes_min": 6}, duration_minutes=6) is True
    assert match_rule({"duration_minutes_min": 6}, duration_minutes=5) is False
    assert match_rule({}, duration_minutes=12) is True
    assert match_rule({"duration_minutes_max": 5}, duration_minutes=None) is False


def test_draft_model_from_metrics():
    metrics = {
        "stages": [
            {"stage": "episode_plan", "model": "plan-m"},
            {"stage": "draft", "model": "draft-m", "tier": "mini"},
        ]
    }
    assert draft_model_from_metrics(metrics) == "draft-m"
    assert draft_model_from_metrics({}) is None


def _model_row(**kwargs):
    return SimpleNamespace(**kwargs)


@pytest.mark.asyncio
async def test_route_binds_llm_model_instance_cross_provider():
    mini = _model_row(
        id=11,
        provider="openai",
        model_id="gpt-4o-mini",
        tier="mini",
        enabled=True,
    )
    pro = _model_row(
        id=22,
        provider="doubao",
        model_id="doubao-pro",
        tier="pro",
        enabled=True,
    )
    db = AsyncMock()

    with (
        patch(
            "app.services.llm_routing.get_runtime_overrides",
            AsyncMock(return_value={}),
        ),
        patch(
            "app.services.llm_routing.resolve_model_from_rules",
            AsyncMock(
                side_effect=[
                    (mini, "route:短故事→llm_models#11"),
                    (pro, "route:长故事→llm_models#22"),
                ]
            ),
        ),
    ):
        short = await resolve_llm_choice(
            db,
            ResolveContext(stage="story_draft", duration_minutes=5, default_provider="doubao"),
        )
        long = await resolve_llm_choice(
            db,
            ResolveContext(stage="story_draft", duration_minutes=6, default_provider="doubao"),
        )

    assert short.provider == "openai"
    assert short.model == "gpt-4o-mini"
    assert short.tier == "mini"
    assert short.llm_model_id == 11
    assert "route:短故事→llm_models#11" in short.reasons
    assert long.provider == "doubao"
    assert long.model == "doubao-pro"
    assert long.llm_model_id == 22


@pytest.mark.asyncio
async def test_no_rule_match_falls_back_env():
    db = AsyncMock()
    with (
        patch(
            "app.services.llm_routing.get_runtime_overrides",
            AsyncMock(return_value={}),
        ),
        patch(
            "app.services.llm_routing.resolve_model_from_rules",
            AsyncMock(return_value=(None, None)),
        ),
        patch(
            "app.services.llm_routing.env_story_model",
            return_value="env-plan-model",
        ),
    ):
        plan = await resolve_llm_choice(
            db,
            ResolveContext(
                stage="story_episode_plan",
                duration_minutes=10,
                default_provider="doubao",
            ),
        )
    assert plan.tier is None
    assert plan.model == "env-plan-model"
    assert plan.provider == "doubao"
    assert "fallback:env" in plan.reasons


@pytest.mark.asyncio
async def test_force_and_agent_override():
    db = AsyncMock()
    with patch(
        "app.services.llm_routing.get_runtime_overrides",
        AsyncMock(return_value={"story_model": "forced-model", "story_provider": "openai"}),
    ):
        choice = await resolve_llm_choice(
            db,
            ResolveContext(stage="story_draft", duration_minutes=3, default_provider="doubao"),
        )
    assert choice.model == "forced-model"
    assert choice.provider == "openai"
    assert choice.tier is None
    assert "force:runtime_story_model" in choice.reasons

    with patch(
        "app.services.llm_routing.get_runtime_overrides",
        AsyncMock(return_value={}),
    ):
        pinned = await resolve_llm_choice(
            db,
            ResolveContext(
                stage="story_draft",
                duration_minutes=3,
                default_provider="doubao",
                agent_model="agent-pinned",
            ),
        )
    assert pinned.model == "agent-pinned"
    assert "agent:model" in pinned.reasons


@pytest.mark.asyncio
async def test_disabled_or_missing_route_target_falls_back_env():
    db = AsyncMock()
    with (
        patch(
            "app.services.llm_routing.get_runtime_overrides",
            AsyncMock(return_value={}),
        ),
        patch(
            "app.services.llm_routing.resolve_model_from_rules",
            AsyncMock(return_value=(None, None)),
        ),
        patch(
            "app.services.llm_routing.env_story_model",
            return_value="env-fallback",
        ),
    ):
        choice = await resolve_llm_choice(
            db,
            ResolveContext(stage="story_draft", duration_minutes=4, default_provider="doubao"),
        )
    assert choice.model == "env-fallback"
    assert "fallback:env" in choice.reasons
