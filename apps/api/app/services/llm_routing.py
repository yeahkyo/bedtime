"""LLM model registry + routing: resolve provider/model via llm_models rows."""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import SessionLocal
from app.models.llm_model import LlmModel
from app.models.llm_routing_rule import LlmRoutingRule
from app.services.provider_settings import (
    STORY_PROVIDERS,
    env_story_model,
    get_runtime_overrides,
)

logger = logging.getLogger(__name__)

TIERS = ("mini", "lite", "pro")


@dataclass(frozen=True)
class ResolveContext:
    stage: str  # agent id, e.g. story_draft
    duration_minutes: int | None = None
    language: str | None = None
    default_provider: str = ""
    agent_provider: str | None = None
    agent_model: str | None = None
    # Reserved for future entitlement / prefs (ignored in phase 1).
    max_tier: str | None = None
    story_quality: str | None = None


@dataclass(frozen=True)
class LlmChoice:
    provider: str
    model: str
    tier: str | None
    llm_model_id: int | None = None
    reasons: tuple[str, ...] = field(default_factory=tuple)

    def reason_str(self) -> str:
        return "; ".join(self.reasons)


def _normalize_provider(raw: str | None, fallback: str = "doubao") -> str:
    p = (raw or "").strip().lower() or fallback
    if p not in STORY_PROVIDERS:
        return fallback
    return p


def _parse_match(raw: str | None) -> dict[str, Any]:
    try:
        data = json.loads(raw or "{}")
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def match_rule(
    match: dict[str, Any],
    *,
    duration_minutes: int | None,
) -> bool:
    """Return True if context satisfies match_json constraints."""
    if not match:
        return True
    if "duration_minutes_max" in match:
        if duration_minutes is None:
            return False
        try:
            if int(duration_minutes) > int(match["duration_minutes_max"]):
                return False
        except (TypeError, ValueError):
            return False
    if "duration_minutes_min" in match:
        if duration_minutes is None:
            return False
        try:
            if int(duration_minutes) < int(match["duration_minutes_min"]):
                return False
        except (TypeError, ValueError):
            return False
    return True


async def seed_llm_routing_rules_if_missing(db: AsyncSession) -> int:
    """No auto-seed: rules must bind to llm_models rows created in Admin."""
    _ = db
    return 0


def choice_from_model_row(
    row: LlmModel,
    *,
    reasons: list[str],
) -> LlmChoice:
    tier = (row.tier or "").strip().lower() or None
    if tier not in TIERS:
        tier = None
    return LlmChoice(
        provider=_normalize_provider(row.provider),
        model=(row.model_id or "").strip(),
        tier=tier,
        llm_model_id=int(row.id) if row.id is not None else None,
        reasons=tuple(reasons),
    )


async def resolve_model_from_rules(
    db: AsyncSession,
    *,
    stage: str,
    duration_minutes: int | None,
) -> tuple[LlmModel | None, str | None]:
    """First matching enabled rule with a usable llm_models row."""
    rows = (
        await db.execute(
            select(LlmRoutingRule)
            .where(
                LlmRoutingRule.stage == stage,
                LlmRoutingRule.enabled.is_(True),
            )
            .order_by(LlmRoutingRule.priority.asc(), LlmRoutingRule.id.asc())
        )
    ).scalars().all()
    for row in rows:
        match = _parse_match(row.match_json)
        if not match_rule(match, duration_minutes=duration_minutes):
            continue
        mid = row.target_llm_model_id
        if mid is None:
            continue
        model = await db.get(LlmModel, int(mid))
        if model is None or not model.enabled:
            continue
        if not (model.model_id or "").strip():
            continue
        label = (row.label_zh or "").strip() or f"rule#{row.id}"
        return model, f"route:{label}→llm_models#{model.id}"
    return None, None


async def resolve_llm_choice(
    db: AsyncSession,
    ctx: ResolveContext,
) -> LlmChoice:
    """
    Priority: runtime force story_model → agent model pin → routing (llm_models
    instance) → env default for fallback provider.
    """
    reasons: list[str] = []
    fallback_provider = _normalize_provider(
        ctx.agent_provider or ctx.default_provider
    )

    overrides = await get_runtime_overrides()
    if overrides.get("story_provider"):
        fallback_provider = _normalize_provider(overrides["story_provider"])
        reasons.append(f"provider:runtime:{fallback_provider}")

    force_model = (overrides.get("story_model") or "").strip()
    if force_model:
        reasons.append("force:runtime_story_model")
        return LlmChoice(
            provider=fallback_provider,
            model=force_model,
            tier=None,
            reasons=tuple(reasons),
        )

    agent_model = (ctx.agent_model or "").strip()
    if agent_model:
        reasons.append("agent:model")
        return LlmChoice(
            provider=fallback_provider,
            model=agent_model,
            tier=None,
            reasons=tuple(reasons),
        )

    stage = (ctx.stage or "").strip()
    if stage:
        model_row, route_reason = await resolve_model_from_rules(
            db, stage=stage, duration_minutes=ctx.duration_minutes
        )
        if model_row is not None and route_reason:
            reasons.append(route_reason)
            return choice_from_model_row(model_row, reasons=reasons)

    env_mid = env_story_model(fallback_provider)
    reasons.append("fallback:env")
    return LlmChoice(
        provider=fallback_provider,
        model=env_mid,
        tier=None,
        reasons=tuple(reasons),
    )


async def resolve_llm_choice_standalone(ctx: ResolveContext) -> LlmChoice:
    async with SessionLocal() as db:
        return await resolve_llm_choice(db, ctx)


def draft_model_from_metrics(metrics: dict[str, Any] | None) -> str | None:
    """Pick draft-stage model from pipeline metrics for stories.story_model."""
    if not isinstance(metrics, dict):
        return None
    stages = metrics.get("stages")
    if not isinstance(stages, list):
        return None
    for row in reversed(stages):
        if not isinstance(row, dict):
            continue
        if row.get("stage") != "draft":
            continue
        mid = row.get("model")
        if isinstance(mid, str) and mid.strip():
            return mid.strip()
    return None
