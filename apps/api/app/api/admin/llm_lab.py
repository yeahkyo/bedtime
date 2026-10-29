"""Admin LLM lab: assemble story-agent prompts from StoryRequest, optionally override
templates (still via {{user_payload}} rendering), preview or call the model."""

from __future__ import annotations

import json
import logging
import time
from dataclasses import replace
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.providers.base import StoryRequest
from app.providers.story_pipeline import (
    OUTLINE_MAX_TOKENS,
    OUTLINE_TIMEOUT_SECONDS,
    PLAN_MAX_TOKENS,
    PLAN_TIMEOUT_SECONDS,
    _parse_stage_json,
    _story_extra_vars,
)
from app.providers.story_prompt import (
    build_outline_user_message,
    build_plan_user_message,
    build_user_message,
    max_tokens_for_story,
    story_http_timeout_seconds,
)
from app.services.errors import safe_error_message
from app.services.llm_agents import (
    AGENT_IDS,
    AgentConfig,
    build_chat_messages,
    get_agent_stored,
    resolve_temperature,
)
from app.services.llm_agents_chat import chat_with_provider
from app.services.llm_routing import ResolveContext, resolve_llm_choice
from app.services.provider_settings import resolve_story_provider_name

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/llm-lab", tags=["admin-llm-lab"])

STORY_LAB_AGENTS = (
    "story_episode_plan",
    "story_series_outline",
    "story_draft",
)

StageName = Literal["episode_plan", "series_outline", "draft"]


class LlmLabDefaultsOut(BaseModel):
    agent_id: str
    label_zh: str
    description: str
    system_prompt: str
    user_prompt_template: str
    max_tokens: int | None
    timeout_seconds: int | None
    temperature: float | None
    provider: str | None
    model: str | None
    from_db: bool
    enabled: bool = True
    placeholders: list[dict[str, str]]


class LlmLabBody(BaseModel):
    agent_id: str = Field(default="story_episode_plan", max_length=64)
    # StoryRequest-ish inputs (assembled into user_payload by code).
    theme: str = Field(default="我不想睡觉", max_length=280)
    theme_mode: str = Field(default="seed", pattern="^(seed|plot)$")
    language: str = Field(default="zh", max_length=16)
    age_band: str = Field(default="3-5", max_length=16)
    duration_minutes: int = Field(default=5, ge=2, le=12)
    wonder: str = Field(default="soft", max_length=32)
    dialogue: str = Field(default="some", max_length=32)
    child_nickname: str = Field(default="豆豆", max_length=64)
    child_gender: str | None = Field(default="unspecified", max_length=32)
    child_age_years: int | None = Field(default=4, ge=0, le=18)
    audiences: list[dict[str, Any]] = Field(default_factory=list)
    roster: list[dict[str, Any]] = Field(default_factory=list)
    soft_series_mode: bool = False
    episode_count: int = Field(default=4, ge=2, le=8)
    episode_no: int = Field(default=1, ge=1, le=8)
    need_series_outline: bool = False
    # Required for draft (plan JSON). Optional otherwise.
    plan: dict[str, Any] | None = None
    # Optional template overrides — still rendered with {{user_payload}} etc.
    system_prompt: str | None = None
    user_prompt_template: str | None = None
    temperature: float | None = Field(default=None, ge=0.0, le=2.0)


class LlmLabPreviewOut(BaseModel):
    agent_id: str
    stage: StageName
    user_payload: str
    system: str
    user: str
    extra_vars: dict[str, Any]
    resolved_provider: str | None = None
    resolved_model: str | None = None
    max_tokens: int
    timeout_seconds: float
    temperature: float
    from_db: bool


class LlmLabRunOut(LlmLabPreviewOut):
    raw_content: str
    parsed: dict[str, Any] | None = None
    parse_error: str | None = None
    ms: int
    usage: dict[str, Any] = Field(default_factory=dict)


def _stage_for_agent(agent_id: str) -> StageName:
    if agent_id == "story_series_outline":
        return "series_outline"
    if agent_id == "story_episode_plan":
        return "episode_plan"
    if agent_id == "story_draft":
        return "draft"
    raise HTTPException(
        status_code=400,
        detail=f"llm-lab supports {', '.join(STORY_LAB_AGENTS)}",
    )


def _build_request(body: LlmLabBody) -> StoryRequest:
    audiences = body.audiences or [
        {
            "name": body.child_nickname,
            "age": body.child_age_years,
            "gender": body.child_gender or "unspecified",
        }
    ]
    return StoryRequest(
        child_nickname=body.child_nickname.strip() or "豆豆",
        age_band=body.age_band,
        language=body.language,
        theme=(body.theme or "").strip() or "睡前小故事",
        theme_mode=body.theme_mode,
        theme_source="user",
        duration_minutes=body.duration_minutes,
        audiences=audiences,
        roster=body.roster or None,
        child_gender=body.child_gender,
        child_age_years=body.child_age_years,
        wonder=body.wonder,
        dialogue=body.dialogue,
        soft_series_mode=body.soft_series_mode,
        episode_count=body.episode_count,
        episode_no=body.episode_no,
        need_series_outline=body.need_series_outline
        or (body.agent_id == "story_series_outline"),
    )


def _user_payload(agent_id: str, req: StoryRequest, plan: dict | None) -> str:
    if agent_id == "story_series_outline":
        return build_outline_user_message(req)
    if agent_id == "story_episode_plan":
        return build_plan_user_message(req)
    if agent_id == "story_draft":
        if not isinstance(plan, dict) or not plan:
            raise HTTPException(
                status_code=400,
                detail="story_draft requires a non-empty plan JSON object",
            )
        return build_user_message(req, plan)
    raise HTTPException(status_code=400, detail=f"unsupported agent: {agent_id}")


def _default_budget(agent_id: str, req: StoryRequest) -> tuple[int, float]:
    if agent_id == "story_series_outline":
        return OUTLINE_MAX_TOKENS, OUTLINE_TIMEOUT_SECONDS
    if agent_id == "story_episode_plan":
        return PLAN_MAX_TOKENS, PLAN_TIMEOUT_SECONDS
    return (
        max_tokens_for_story(req.language, req.duration_minutes),
        float(story_http_timeout_seconds(req.duration_minutes)),
    )


def _apply_overrides(agent: AgentConfig, body: LlmLabBody) -> AgentConfig:
    updates: dict[str, Any] = {}
    if body.system_prompt is not None:
        updates["system_prompt"] = body.system_prompt
    if body.user_prompt_template is not None:
        updates["user_prompt_template"] = body.user_prompt_template
    if body.temperature is not None:
        updates["temperature"] = body.temperature
    return replace(agent, **updates) if updates else agent


async def _assemble(
    db: AsyncSession, body: LlmLabBody
) -> tuple[AgentConfig, StoryRequest, str, dict[str, Any], str, str, int, float, str, str | None]:
    if body.agent_id not in STORY_LAB_AGENTS:
        raise HTTPException(
            status_code=400,
            detail=f"llm-lab supports {', '.join(STORY_LAB_AGENTS)}",
        )
    if body.agent_id not in AGENT_IDS:
        raise HTTPException(status_code=400, detail="unknown agent id")

    # Use stored row (incl. disabled) so lab edits match Agents DB, not runtime fallback.
    agent = _apply_overrides(await get_agent_stored(db, body.agent_id), body)
    if not (agent.system_prompt or "").strip():
        raise HTTPException(status_code=400, detail="system_prompt is empty")

    req = _build_request(body)
    user_payload = _user_payload(body.agent_id, req, body.plan)
    extra = _story_extra_vars(req)
    system, user = build_chat_messages(
        agent, user_payload=user_payload, extra_vars=extra
    )
    default_tokens, default_timeout = _default_budget(body.agent_id, req)
    max_tokens = int(agent.max_tokens) if agent.max_tokens else default_tokens
    timeout = (
        float(agent.timeout_seconds) if agent.timeout_seconds else default_timeout
    )

    job_provider = await resolve_story_provider_name()
    agent_provider = (agent.provider or "").strip().lower() or None
    choice = await resolve_llm_choice(
        db,
        ResolveContext(
            stage=agent.id,
            duration_minutes=req.duration_minutes,
            language=req.language,
            default_provider=job_provider,
            agent_provider=agent_provider,
            agent_model=(agent.model or "").strip() or None,
        ),
    )
    return (
        agent,
        req,
        user_payload,
        extra,
        system,
        user,
        max_tokens,
        timeout,
        choice.provider,
        choice.model,
    )


@router.get("/defaults", response_model=LlmLabDefaultsOut)
async def llm_lab_defaults(
    agent_id: str = "story_episode_plan",
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmLabDefaultsOut:
    if agent_id not in STORY_LAB_AGENTS:
        raise HTTPException(
            status_code=400,
            detail=f"llm-lab supports {', '.join(STORY_LAB_AGENTS)}",
        )
    agent = await get_agent_stored(db, agent_id)
    return LlmLabDefaultsOut(
        agent_id=agent.id,
        label_zh=agent.label_zh,
        description=agent.description,
        system_prompt=agent.system_prompt,
        user_prompt_template=agent.user_prompt_template,
        max_tokens=agent.max_tokens,
        timeout_seconds=agent.timeout_seconds,
        temperature=agent.temperature,
        provider=agent.provider,
        model=agent.model,
        from_db=agent.from_db,
        enabled=agent.enabled,
        placeholders=agent.placeholders,
    )


@router.post("/preview", response_model=LlmLabPreviewOut)
async def llm_lab_preview(
    body: LlmLabBody,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmLabPreviewOut:
    (
        agent,
        _req,
        user_payload,
        extra,
        system,
        user,
        max_tokens,
        timeout,
        provider,
        model,
    ) = await _assemble(db, body)
    return LlmLabPreviewOut(
        agent_id=agent.id,
        stage=_stage_for_agent(agent.id),
        user_payload=user_payload,
        system=system,
        user=user,
        extra_vars=extra,
        resolved_provider=provider,
        resolved_model=model,
        max_tokens=max_tokens,
        timeout_seconds=timeout,
        temperature=resolve_temperature(agent.temperature),
        from_db=agent.from_db,
    )


@router.post("/run", response_model=LlmLabRunOut)
async def llm_lab_run(
    body: LlmLabBody,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmLabRunOut:
    (
        agent,
        _req,
        user_payload,
        extra,
        system,
        user,
        max_tokens,
        timeout,
        provider,
        model,
    ) = await _assemble(db, body)
    stage = _stage_for_agent(agent.id)
    t0 = time.perf_counter()
    try:
        outcome = await chat_with_provider(
            provider=provider,
            model=model,
            system=system,
            user=user,
            max_tokens=max_tokens,
            timeout=timeout,
            stage=stage,
            temperature=agent.temperature,
        )
    except Exception as exc:
        logger.exception("llm-lab run failed agent=%s provider=%s", agent.id, provider)
        raise HTTPException(
            status_code=502,
            detail=safe_error_message(exc, fallback="LLM lab call failed"),
        ) from exc
    ms = int((time.perf_counter() - t0) * 1000)
    raw = outcome.content or ""
    parsed: dict[str, Any] | None = None
    parse_error: str | None = None
    try:
        parsed = _parse_stage_json(stage, raw)
    except Exception as exc:
        parse_error = str(exc)
        # Still return raw so operators can inspect truncated / non-JSON replies.
        try:
            maybe = json.loads(raw)
            if isinstance(maybe, dict):
                parsed = maybe
                parse_error = f"stage parse failed ({exc}); returned raw JSON object"
        except Exception:
            pass

    return LlmLabRunOut(
        agent_id=agent.id,
        stage=stage,
        user_payload=user_payload,
        system=system,
        user=user,
        extra_vars=extra,
        resolved_provider=provider,
        resolved_model=model,
        max_tokens=max_tokens,
        timeout_seconds=timeout,
        temperature=resolve_temperature(agent.temperature),
        from_db=agent.from_db,
        raw_content=raw,
        parsed=parsed,
        parse_error=parse_error,
        ms=ms,
        usage=outcome.usage_dict(),
    )
