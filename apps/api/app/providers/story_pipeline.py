"""Shared outline → episode-plan → draft LLM orchestration for story providers."""

from __future__ import annotations

import json
import logging
import time
from collections.abc import Awaitable, Callable
from typing import Any

from app.providers.base import StoryRequest, StoryResult
from app.providers.chat_usage import (
    ChatOutcome,
    coerce_chat_outcome,
    merge_stage_rows,
    metrics_payload,
)
from app.providers.story_prompt import (
    build_outline_user_message,
    build_plan_user_message,
    build_user_message,
    clamp_episode_count,
    ensure_soft_hook_in_body,
    max_tokens_for_story,
    normalize_series_outline,
    parse_json_object,
    story_http_timeout_seconds,
    validate_episode_plan,
)
from app.services.llm_agents import (
    AgentConfig,
    build_chat_messages,
    get_agent_standalone,
    resolve_temperature,
)
from app.services.llm_routing import ResolveContext, resolve_llm_choice_standalone

logger = logging.getLogger(__name__)

# Reasoning models often exceed 60s even for short JSON plans/outlines.
OUTLINE_TIMEOUT_SECONDS = 180.0
PLAN_TIMEOUT_SECONDS = 120.0
# Outlines were truncating at 1200 (finish_reason=length → broken JSON).
OUTLINE_MAX_TOKENS = 4096
PLAN_MAX_TOKENS = 2048

ChatFn = Callable[..., Awaitable[str | ChatOutcome]]
ProgressFn = Callable[[str], Awaitable[None]]
PlanFn = Callable[[dict[str, Any]], Awaitable[None]]


def _parse_stage_json(stage: str, raw: str) -> dict:
    try:
        return parse_json_object(raw)
    except Exception as exc:
        preview = (raw or "").replace("\n", " ")[:280]
        raise ValueError(
            f"{stage} returned invalid/truncated JSON: {exc}; preview={preview!r}"
        ) from exc


def _story_extra_vars(request: StoryRequest) -> dict[str, Any]:
    """Scalars for Agent templates outside user_payload (outline lead needs count)."""
    from app.providers.story_prompt import clamp_episode_count

    return {
        "episode_count": clamp_episode_count(request.episode_count),
    }


def dumps_submitted_prompts(stages: list[dict[str, Any]] | None) -> str | None:
    if not stages:
        return None
    return json.dumps({"stages": stages}, ensure_ascii=False)


def loads_submitted_prompts(raw: str | None) -> list[dict[str, Any]]:
    if not (raw or "").strip():
        return []
    try:
        loaded = json.loads(raw)
    except json.JSONDecodeError:
        return []
    if isinstance(loaded, dict):
        stages = loaded.get("stages")
    elif isinstance(loaded, list):
        stages = loaded
    else:
        return []
    if not isinstance(stages, list):
        return []
    return [row for row in stages if isinstance(row, dict)]


def merge_submitted_prompts(
    prior_raw: str | None,
    newer_stages: list[dict[str, Any]] | None,
) -> str | None:
    """Merge prompt stages across attempts (plan from first try + draft on retry)."""
    merged = merge_stage_rows(loads_submitted_prompts(prior_raw), newer_stages)
    return dumps_submitted_prompts(merged)


def _is_truncated_error(exc: BaseException) -> bool:
    from app.providers.deepseek_budget import DeepSeekTruncatedError

    if isinstance(exc, DeepSeekTruncatedError):
        return True
    msg = str(exc).lower()
    return "truncated" in msg or "finish_reason=length" in msg or "empty content" in msg


async def _chat_json(
    chat: ChatFn,
    *,
    system: str,
    user: str,
    stage: str,
    max_tokens: int,
    timeout: float,
    retries: int = 0,
    model: str | None = None,
    provider_override: str | None = None,
    effective_provider: str | None = None,
    temperature: float | None = None,
    stage_metrics: list[dict[str, Any]] | None = None,
    choice_tier: str | None = None,
    policy_reason: str | None = None,
) -> dict:
    """max_tokens is visible JSON (content) budget. Truncation retries prefer
    disabling thinking over inflating the budget (cheaper than a second fat CoT).
    """
    last_err: Exception | None = None
    # content budget only — provider adds CoT reserve when thinking is on
    tokens = max_tokens
    thinking_override: bool | None = None
    effort_override: str | None = None
    temp = resolve_temperature(temperature)
    for attempt in range(retries + 1):
        t0 = time.perf_counter()
        try:
            if provider_override:
                from app.services.llm_agents_chat import chat_with_provider

                raw = await chat_with_provider(
                    provider=provider_override,
                    model=model,
                    system=system,
                    user=user,
                    max_tokens=tokens,
                    timeout=timeout,
                    stage=stage,
                    thinking=thinking_override,
                    reasoning_effort=effort_override,
                    temperature=temp,
                )
            else:
                raw = await chat(
                    system,
                    user,
                    max_tokens=tokens,
                    timeout=timeout,
                    stage=stage,
                    model=model,
                    thinking=thinking_override,
                    reasoning_effort=effort_override,
                    temperature=temp,
                )
            outcome = coerce_chat_outcome(raw)
            data = _parse_stage_json(stage, outcome.content)
            ms = int((time.perf_counter() - t0) * 1000)
            logger.info(
                "story_timing stage=%s attempt=%s ok ms=%s content_budget=%s "
                "thinking=%s chars=%s tokens=%s",
                stage,
                attempt + 1,
                ms,
                tokens,
                thinking_override,
                len(outcome.content or ""),
                outcome.usage_dict() or None,
            )
            if stage_metrics is not None:
                row: dict[str, Any] = {"stage": stage, "ms": ms, "attempt": attempt + 1}
                if effective_provider:
                    row["provider"] = effective_provider
                if model:
                    row["model"] = model
                if choice_tier:
                    row["tier"] = choice_tier
                if policy_reason:
                    row["policy_reason"] = policy_reason
                row.update(outcome.usage_dict())
                stage_metrics.append(row)
            return data
        except Exception as exc:
            ms = int((time.perf_counter() - t0) * 1000)
            last_err = exc
            logger.warning(
                "story_timing stage=%s attempt=%s fail ms=%s content_budget=%s "
                "thinking=%s err=%s",
                stage,
                attempt + 1,
                ms,
                tokens,
                thinking_override,
                type(exc).__name__,
            )
            if attempt >= retries:
                break
            if _is_truncated_error(exc) and thinking_override is not False:
                # Prefer cheaper retry: drop CoT instead of doubling max_tokens.
                thinking_override = False
                effort_override = None
                tokens = min(8192, max(tokens, int(max_tokens * 1.15)))
                logger.info(
                    "story_timing stage=%s retry_policy=disable_thinking "
                    "content_budget=%s",
                    stage,
                    tokens,
                )
            else:
                # Invalid JSON / already no-thinking: modest content bump only.
                tokens = min(8192, max(int(tokens * 1.25), tokens + 512))
                logger.info(
                    "story_timing stage=%s retry_policy=content_bump "
                    "content_budget=%s",
                    stage,
                    tokens,
                )
    assert last_err is not None
    raise last_err


async def _run_agent_stage(
    chat: ChatFn,
    *,
    agent: AgentConfig,
    user_payload: str,
    extra_vars: dict[str, Any],
    stage: str,
    default_max_tokens: int,
    default_timeout: float,
    default_provider: str,
    duration_minutes: int | None = None,
    language: str | None = None,
    retries: int = 1,
    stage_metrics: list[dict[str, Any]] | None = None,
    stage_prompts: list[dict[str, str]] | None = None,
) -> dict:
    system, user = build_chat_messages(
        agent, user_payload=user_payload, extra_vars=extra_vars
    )
    if stage_prompts is not None:
        stage_prompts.append({"stage": stage, "system": system, "user": user})
    max_tokens = int(agent.max_tokens) if agent.max_tokens else default_max_tokens
    timeout = (
        float(agent.timeout_seconds) if agent.timeout_seconds else default_timeout
    )
    agent_provider = (agent.provider or "").strip().lower() or None
    choice = await resolve_llm_choice_standalone(
        ResolveContext(
            stage=agent.id,
            duration_minutes=duration_minutes,
            language=language,
            default_provider=default_provider,
            agent_provider=agent_provider,
            agent_model=(agent.model or "").strip() or None,
        )
    )
    effective_provider = choice.provider
    model = choice.model
    # Job chat is bound to default_provider; cross-provider (route/agent) needs override.
    job_provider = (default_provider or "").strip().lower()
    chat_provider_override = (
        effective_provider
        if effective_provider and effective_provider != job_provider
        else None
    )
    return await _chat_json(
        chat,
        system=system,
        user=user,
        stage=stage,
        max_tokens=max_tokens,
        timeout=timeout,
        retries=retries,
        model=model,
        provider_override=chat_provider_override,
        effective_provider=effective_provider,
        temperature=agent.temperature,
        stage_metrics=stage_metrics,
        choice_tier=choice.tier,
        policy_reason=choice.reason_str() or None,
    )


async def run_story_pipeline(
    request: StoryRequest,
    *,
    chat: ChatFn,
    on_progress: ProgressFn | None = None,
    on_plan: PlanFn | None = None,
    default_provider: str | None = None,
) -> StoryResult:
    """
    chat(...) -> str | ChatOutcome
    on_progress(stage) optional DB/UI progress hook
    on_plan(plan) optional checkpoint after episode_plan validates
    default_provider: job-level story provider (doubao/openai/deepseek) for metrics
    """
    from app.services.provider_settings import resolve_story_provider_name

    pipeline_t0 = time.perf_counter()
    extra = _story_extra_vars(request)
    stage_metrics: list[dict[str, Any]] = []
    stage_prompts: list[dict[str, str]] = []
    partial: dict[str, Any] = {"episode_plan": None}
    job_provider = (
        (default_provider or "").strip().lower()
        or await resolve_story_provider_name()
    )
    try:
        return await _run_story_pipeline_body(
            request,
            chat=chat,
            on_progress=on_progress,
            on_plan=on_plan,
            pipeline_t0=pipeline_t0,
            extra=extra,
            stage_metrics=stage_metrics,
            stage_prompts=stage_prompts,
            partial=partial,
            job_provider=job_provider,
        )
    except Exception as exc:
        if stage_prompts and not getattr(exc, "submitted_prompts", None):
            setattr(exc, "submitted_prompts", list(stage_prompts))
        if stage_metrics and not getattr(exc, "submitted_metrics", None):
            setattr(
                exc,
                "submitted_metrics",
                metrics_payload(stages=list(stage_metrics)),
            )
        plan = partial.get("episode_plan")
        if plan is not None and not getattr(exc, "submitted_episode_plan", None):
            setattr(exc, "submitted_episode_plan", plan)
        raise


async def _run_story_pipeline_body(
    request: StoryRequest,
    *,
    chat: ChatFn,
    on_progress: ProgressFn | None,
    on_plan: PlanFn | None,
    pipeline_t0: float,
    extra: dict[str, Any],
    stage_metrics: list[dict[str, Any]],
    stage_prompts: list[dict[str, str]],
    partial: dict[str, Any],
    job_provider: str,
) -> StoryResult:
    async def _progress(stage: str) -> None:
        if on_progress is not None:
            await on_progress(stage)

    outline: dict[str, Any] | None = request.series_outline
    new_outline: dict[str, Any] | None = None
    series_title: str | None = None
    episode_no = max(1, int(request.episode_no or 1))

    should_build_outline = request.need_series_outline or (
        request.soft_series_mode and outline is None
    )
    if should_build_outline:
        request.episode_count = clamp_episode_count(request.episode_count)
        await _progress("series_outline")
        outline_agent = await get_agent_standalone("story_series_outline")
        outline = await _run_agent_stage(
            chat,
            agent=outline_agent,
            user_payload=build_outline_user_message(request),
            extra_vars=extra,
            stage="series_outline",
            default_max_tokens=OUTLINE_MAX_TOKENS,
            default_timeout=OUTLINE_TIMEOUT_SECONDS,
            default_provider=job_provider,
            duration_minutes=request.duration_minutes,
            language=request.language,
            retries=1,
            stage_metrics=stage_metrics,
            stage_prompts=stage_prompts,
        )
        outline = normalize_series_outline(outline)
        _validate_outline(outline, request.episode_count)
        new_outline = outline
        series_title = str(outline.get("title") or "") or None
        episode_no = 1

    if outline is not None:
        # Accept legacy long-key outlines already stored in DB.
        outline = normalize_series_outline(outline)
        request.series_outline = outline
        request.episode_no = episode_no
        request.soft_series_mode = True

    # Prefer outline focus when continuing a series episode (metadata only).
    if outline is not None:
        from app.providers.story_prompt import focus_from_series_outline

        oid, _ohow = focus_from_series_outline(
            outline, episode_no, age_band=request.age_band
        )
        if oid:
            request.development_focus = oid

    reused_plan = request.episode_plan
    if isinstance(reused_plan, dict) and reused_plan:
        await _progress("episode_plan")
        plan = validate_episode_plan(reused_plan)
        partial["episode_plan"] = plan
        # Placeholder so admin still shows the stage; merge keeps real prior timings.
        stage_metrics.append(
            {
                "stage": "episode_plan",
                "ms": 0,
                "skipped": True,
                "reason": "resume_saved_plan",
            }
        )
        logger.info(
            "story_timing stage=episode_plan skip_llm reason=resume_saved_plan "
            "title=%s beats=%s",
            plan.get("title"),
            len(plan.get("beats") or []),
        )
    else:
        await _progress("episode_plan")
        plan_agent = await get_agent_standalone("story_episode_plan")
        plan = validate_episode_plan(
            await _run_agent_stage(
                chat,
                agent=plan_agent,
                user_payload=build_plan_user_message(request),
                extra_vars=extra,
                stage="episode_plan",
                default_max_tokens=PLAN_MAX_TOKENS,
                default_timeout=PLAN_TIMEOUT_SECONDS,
                default_provider=job_provider,
                duration_minutes=request.duration_minutes,
                language=request.language,
                retries=1,
                stage_metrics=stage_metrics,
                stage_prompts=stage_prompts,
            )
        )
        partial["episode_plan"] = plan
        if on_plan is not None:
            await on_plan(plan)

    await _progress("draft")
    draft_timeout = story_http_timeout_seconds(request.duration_minutes)
    draft_agent = await get_agent_standalone("story_draft")
    data = await _run_agent_stage(
        chat,
        agent=draft_agent,
        user_payload=build_user_message(request, plan),
        extra_vars=extra,
        stage="draft",
        default_max_tokens=max_tokens_for_story(request.language, request.duration_minutes),
        default_timeout=draft_timeout,
        default_provider=job_provider,
        duration_minutes=request.duration_minutes,
        language=request.language,
        retries=2,
        stage_metrics=stage_metrics,
        stage_prompts=stage_prompts,
    )
    soft_hook = data.get("hook") if data.get("hook") is not None else data.get("soft_hook")
    if request.soft_series_mode:
        if not soft_hook:
            soft_hook = plan.get("hook") or plan.get("soft_promise") or None
        if soft_hook == "":
            soft_hook = None
    else:
        soft_hook = None

    body = data.get("body") or ""
    if request.soft_series_mode and soft_hook:
        body = ensure_soft_hook_in_body(body, soft_hook)

    pipeline_ms = int((time.perf_counter() - pipeline_t0) * 1000)
    logger.info(
        "story_timing stage=llm_pipeline ok ms=%s duration_min=%s soft_series=%s outline=%s body_chars=%s",
        pipeline_ms,
        request.duration_minutes,
        bool(request.soft_series_mode),
        should_build_outline,
        len(body or ""),
    )

    return StoryResult(
        title=str(
            data.get("title") or plan.get("title") or plan.get("title_hint") or "睡前故事"
        ),
        body=body,
        soft_hook=soft_hook,
        series_outline=new_outline,
        series_title=series_title,
        episode_no=episode_no if (request.soft_series_mode or new_outline) else None,
        episode_plan=plan,
        metrics=metrics_payload(stages=stage_metrics, pipeline_ms=pipeline_ms),
        prompts=list(stage_prompts),
    )


def _validate_outline(outline: dict, episode_count: int) -> None:
    episodes = outline.get("episodes") or []
    if not isinstance(episodes, list) or len(episodes) != int(episode_count):
        raise ValueError(
            f"series_outline episodes length must equal episode_count={episode_count}"
        )
