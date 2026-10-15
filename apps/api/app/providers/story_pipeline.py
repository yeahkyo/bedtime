"""Shared outline → episode-plan → draft LLM orchestration for story providers."""

from __future__ import annotations

import logging
import time
from collections.abc import Awaitable, Callable
from typing import Any

from app.providers.base import StoryRequest, StoryResult
from app.providers.story_prompt import (
    PLAN_SYSTEM_PROMPT,
    SERIES_OUTLINE_SYSTEM_PROMPT,
    SYSTEM_PROMPT,
    build_outline_user_message,
    build_plan_user_message,
    build_user_message,
    clamp_episode_count,
    ensure_soft_hook_in_body,
    max_tokens_for_story,
    parse_json_object,
    select_beat_pattern,
    select_cast_intro_mode,
    select_opening_pattern,
    story_http_timeout_seconds,
    validate_episode_plan,
)

logger = logging.getLogger(__name__)

# Reasoning models often exceed 60s even for short JSON plans/outlines.
OUTLINE_TIMEOUT_SECONDS = 180.0
PLAN_TIMEOUT_SECONDS = 120.0
# Outlines were truncating at 1200 (finish_reason=length → broken JSON).
OUTLINE_MAX_TOKENS = 4096
PLAN_MAX_TOKENS = 2048

ChatFn = Callable[..., Awaitable[str]]
ProgressFn = Callable[[str], Awaitable[None]]


def _parse_stage_json(stage: str, raw: str) -> dict:
    try:
        return parse_json_object(raw)
    except Exception as exc:
        preview = (raw or "").replace("\n", " ")[:280]
        raise ValueError(
            f"{stage} returned invalid/truncated JSON: {exc}; preview={preview!r}"
        ) from exc


async def _chat_json(
    chat: ChatFn,
    *,
    system: str,
    user: str,
    stage: str,
    max_tokens: int,
    timeout: float,
    retries: int = 0,
) -> dict:
    last_err: Exception | None = None
    tokens = max_tokens
    for attempt in range(retries + 1):
        t0 = time.perf_counter()
        try:
            raw = await chat(
                system,
                user,
                max_tokens=tokens,
                timeout=timeout,
                stage=stage,
            )
            data = _parse_stage_json(stage, raw)
            ms = int((time.perf_counter() - t0) * 1000)
            logger.info(
                "story_timing stage=%s attempt=%s ok ms=%s max_tokens=%s chars=%s",
                stage,
                attempt + 1,
                ms,
                tokens,
                len(raw or ""),
            )
            return data
        except Exception as exc:
            ms = int((time.perf_counter() - t0) * 1000)
            last_err = exc
            logger.warning(
                "story_timing stage=%s attempt=%s fail ms=%s max_tokens=%s err=%s",
                stage,
                attempt + 1,
                ms,
                tokens,
                type(exc).__name__,
            )
            tokens = min(8192, int(tokens * 1.5))
    assert last_err is not None
    raise last_err


async def run_story_pipeline(
    request: StoryRequest,
    *,
    chat: ChatFn,
    on_progress: ProgressFn | None = None,
) -> StoryResult:
    """
    chat(system, user, *, max_tokens, timeout, stage) -> content str
    on_progress(stage) optional DB/UI progress hook
    """
    pipeline_t0 = time.perf_counter()

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
        outline = await _chat_json(
            chat,
            system=SERIES_OUTLINE_SYSTEM_PROMPT,
            user=build_outline_user_message(request),
            stage="series_outline",
            max_tokens=OUTLINE_MAX_TOKENS,
            timeout=OUTLINE_TIMEOUT_SECONDS,
            retries=1,
        )
        _validate_outline(outline, request.episode_count)
        new_outline = outline
        series_title = str(outline.get("title") or "") or None
        episode_no = 1

    if outline is not None:
        request.series_outline = outline
        request.episode_no = episode_no
        request.soft_series_mode = True

    await _progress("episode_plan")
    salt = request.child_nickname or ""
    beat = select_beat_pattern(
        request.development_focus,
        theme=request.theme,
        episode_no=episode_no,
        salt=salt,
    )
    # Prefer outline focus when continuing a series episode.
    if outline is not None:
        from app.providers.story_prompt import focus_from_series_outline

        oid, _ohow = focus_from_series_outline(
            outline, episode_no, age_band=request.age_band
        )
        if oid:
            beat = select_beat_pattern(
                oid,
                theme=request.theme,
                episode_no=episode_no,
                salt=salt,
            )
            request.development_focus = oid

    lead = _lead_level(request)
    opening = select_opening_pattern(
        lead,
        episode_no=episode_no,
        has_recap=bool((request.recap or "").strip()),
        child_cast_absent=(request.child_cast_role or "").lower() == "absent",
        salt=salt,
    )
    intro = select_cast_intro_mode(
        soft_series_mode=bool(request.soft_series_mode or outline),
        episode_no=episode_no,
        lead_in=lead,
    )

    plan = validate_episode_plan(
        await _chat_json(
            chat,
            system=PLAN_SYSTEM_PROMPT,
            user=build_plan_user_message(
                request,
                beat_pattern=beat,
                opening_pattern=opening,
                cast_intro_mode=intro,
            ),
            stage="episode_plan",
            max_tokens=PLAN_MAX_TOKENS,
            timeout=PLAN_TIMEOUT_SECONDS,
            retries=1,
        ),
        lead_in=lead,
        soft_series_mode=bool(request.soft_series_mode),
        beat_pattern=beat,
        opening_pattern=opening,
        cast_intro_mode=intro,
    )

    await _progress("draft")
    draft_timeout = story_http_timeout_seconds(request.duration_minutes)
    data = await _chat_json(
        chat,
        system=SYSTEM_PROMPT,
        user=build_user_message(request, plan),
        stage="draft",
        max_tokens=max_tokens_for_story(request.language, request.duration_minutes),
        timeout=draft_timeout,
        retries=1,
    )
    soft_hook = data.get("soft_hook")
    if request.soft_series_mode:
        if not soft_hook:
            soft_hook = plan.get("soft_hook_hint") or None
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
        title=data.get("title") or plan.get("title_hint") or "Bedtime Story",
        body=body,
        soft_hook=soft_hook,
        series_outline=new_outline,
        series_title=series_title or (str(outline.get("title")) if outline else None),
        episode_no=episode_no if request.soft_series_mode else None,
        episode_plan=plan,
    )


def _lead_level(request: StoryRequest) -> str:
    from app.providers.story_prompt import normalize_dial

    return normalize_dial("lead_in", request.lead_in)


def _validate_outline(outline: dict, episode_count: int) -> None:
    episodes = outline.get("episodes")
    if not isinstance(episodes, list) or len(episodes) < 2:
        raise ValueError("series outline must include episodes[]")
    if len(episodes) < min(2, episode_count):
        raise ValueError("series outline episodes too short")
    outline.setdefault("threads", [])
    outline.setdefault("cast_spine", [])
    outline.setdefault("throughline", "")
    outline.setdefault("title", "晚安小系列")
