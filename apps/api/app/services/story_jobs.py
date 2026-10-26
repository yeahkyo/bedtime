"""Background story generation: LLM pipeline + TTS, with DB progress updates."""

from __future__ import annotations

import json
import logging
import time
from dataclasses import asdict, fields
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.db import SessionLocal
from app.models.child import Child
from app.models.story import Story, StoryAudio
from app.models.story_series import StorySeries
from app.providers.base import StoryRequest, VoiceSettings
from app.providers.chat_usage import (
    merge_job_metrics,
    merge_metrics_dicts,
    merge_stage_rows,
    parse_metrics_json,
)
from app.providers.factory import get_story_provider, get_tts_provider
from app.providers.story_pipeline import merge_submitted_prompts
from app.providers.story_prompt import clamp_episode_count
from app.services.errors import safe_error_message
from app.services.narration_prosody import strip_performance_markers, synthesize_with_prosody
from app.services.provider_settings import (
    first_configured_speech_provider,
    resolve_story_provider_name,
)
from app.services.storage import storage_service
from app.services.story_elements import resolve_story_element_for_job
from app.services.story_job_recovery import (
    TTS_LEASE_PROGRESS,
    is_generating_orphan,
    load_episode_plan_json,
    should_resume_draft_only,
    should_resume_tts_only,
)

logger = logging.getLogger(__name__)

_STORY_REQ_KEYS = {f.name for f in fields(StoryRequest)}


def story_tts_disabled() -> bool:
    """True when STORY_SKIP_TTS is set (temporary text-quality iteration mode)."""
    return bool(get_settings().story_skip_tts)


def serialize_story_request(req: StoryRequest) -> dict[str, Any]:
    return asdict(req)


def deserialize_story_request(data: dict[str, Any]) -> StoryRequest:
    filtered = {k: data[k] for k in _STORY_REQ_KEYS if k in data}
    return StoryRequest(**filtered)


def _touch_progress(story: Story, *, progress: str, status: str | None = None) -> None:
    story.progress = progress
    if status is not None:
        story.status = status
    story.progress_at = datetime.now(timezone.utc)


async def _set_story_progress(
    db,
    story_id: int,
    *,
    progress: str,
    status: str | None = None,
    error_message: str | None = None,
) -> None:
    story = await db.get(Story, story_id)
    if story is None:
        return
    if status == "failed" and (story.status or "") == "ready":
        logger.warning(
            "story_fail skip overwrite ready story_id=%s", story_id
        )
        return
    # Preserve TTS checkpoint on failure so retry can skip LLM.
    if status == "failed" and (story.body or "").strip():
        if (story.progress or "") in ("tts", TTS_LEASE_PROGRESS):
            progress = "tts"
    _touch_progress(story, progress=progress, status=status)
    if error_message is not None:
        story.error_message = error_message[:2000]
    await db.commit()


async def _claim_tts_lease(db, story_id: int) -> bool:
    """Single-flight TTS: only one worker synthesizes; stale leases can be stolen."""
    story = (
        await db.execute(
            select(Story)
            .where(Story.id == story_id)
            .options(selectinload(Story.audio))
        )
    ).scalar_one_or_none()
    if story is None:
        return False
    if (story.status or "") == "ready":
        return False
    if story.audio is not None and (story.audio.object_key or "").strip():
        return False
    if (story.status or "") != "generating":
        return False
    if (story.progress or "") == TTS_LEASE_PROGRESS and not is_generating_orphan(story):
        logger.info("story_tts lease_held story_id=%s", story_id)
        return False
    _touch_progress(story, progress=TTS_LEASE_PROGRESS, status="generating")
    await db.commit()
    return True


async def _finalize_without_tts(
    db,
    *,
    story_id: int,
    job_t0: float,
    llm_ms: int = 0,
    prior_metrics: dict[str, Any] | None = None,
) -> None:
    """Finish LLM-only jobs when STORY_SKIP_TTS is on.

    Must not use status=ready (no StoryAudio). ``text_ready`` means body is done
    but playback is unavailable — clients treat non-ready as not playable.
    """
    story = (
        await db.execute(
            select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
        )
    ).scalar_one_or_none()
    if story is None:
        return
    if (story.status or "") in ("ready", "text_ready") and (story.body or "").strip():
        logger.info("story_skip_tts already_done story_id=%s status=%s", story_id, story.status)
        return
    if not (story.body or "").strip():
        raise RuntimeError("Cannot skip TTS: empty story body")
    # Never mark ready without stored audio (code-review baseline).
    story.status = "text_ready"
    story.error_message = None
    _touch_progress(story, progress="text_ready", status="text_ready")
    total_ms = int((time.perf_counter() - job_t0) * 1000)
    metrics = merge_job_metrics(
        prior_metrics,
        llm_ms=llm_ms,
        tts_ms=0,
        storage_ms=0,
        total_ms=total_ms,
    )
    metrics["tts_skipped"] = True
    story.metrics_json = json.dumps(metrics, ensure_ascii=False)
    await db.commit()
    logger.warning(
        "story_timing story_id=%s stage=tts_skipped ok ms=%s llm_ms=%s body_chars=%s",
        story_id,
        total_ms,
        llm_ms,
        len(story.body or ""),
    )


async def _run_tts_and_store(
    db,
    *,
    story_id: int,
    user_id: int,
    narration_body: str,
    provider_voice_id: str,
    voice_settings: dict[str, Any],
    speech_name: str,
    job_t0: float,
    llm_ms: int = 0,
    prior_metrics: dict[str, Any] | None = None,
) -> None:
    """Shared TTS → storage → ready. Caller must have status=generating."""
    if story_tts_disabled():
        await _finalize_without_tts(
            db,
            story_id=story_id,
            job_t0=job_t0,
            llm_ms=llm_ms,
            prior_metrics=prior_metrics,
        )
        return
    if not await _claim_tts_lease(db, story_id):
        logger.info("story_tts skip no_lease story_id=%s", story_id)
        return
    vs = VoiceSettings(
        **{
            k: voice_settings[k]
            for k in ("speed", "stability", "style", "similarity_boost")
            if k in voice_settings
        }
    )
    from app.models.voice import Voice
    from app.services.provider_settings import resolve_speech_model

    story = await db.get(Story, story_id)
    if story is None:
        return
    voice_model: str | None = (story.speech_model or "").strip() or None
    if not voice_model and story.voice_id is not None:
        voice_row = await db.get(Voice, story.voice_id)
        if voice_row is not None:
            voice_model = (voice_row.speech_model or "").strip() or None

    tts = get_tts_provider(speech_name)
    speech_model = await resolve_speech_model(speech_name, voice_model=voice_model)
    tts_t0 = time.perf_counter()
    synth = await synthesize_with_prosody(
        tts,
        narration_body,
        provider_voice_id,
        vs,
        speech_provider=speech_name,
        model=speech_model,
    )
    audio_bytes = synth.audio
    display_body = synth.display
    tts_ms = int((time.perf_counter() - tts_t0) * 1000)
    logger.info(
        "story_timing story_id=%s stage=tts ok ms=%s audio_bytes=%s provider=%s model=%s "
        "speak_chars=%s used_ssml=%s",
        story_id,
        tts_ms,
        len(audio_bytes),
        speech_name,
        speech_model,
        len(synth.speak_text or ""),
        synth.used_ssml,
    )
    story = await db.get(Story, story_id)
    if story is None:
        return
    if (story.status or "") == "ready":
        logger.warning("story_tts abort already_ready story_id=%s", story_id)
        return
    story.body = display_body or narration_body
    story.speech_provider = speech_name
    if speech_model:
        story.speech_model = speech_model
    await db.commit()

    key = storage_service.new_key(f"stories/{user_id}", ".mp3")
    storage_t0 = time.perf_counter()
    await storage_service.put_bytes(key, audio_bytes, "audio/mpeg")
    storage_ms = int((time.perf_counter() - storage_t0) * 1000)
    logger.info(
        "story_timing story_id=%s stage=storage ok ms=%s",
        story_id,
        storage_ms,
    )

    story = (
        await db.execute(
            select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
        )
    ).scalar_one()
    if (story.status or "") == "ready" and story.audio is not None:
        logger.warning("story_tts abort race_ready story_id=%s", story_id)
        return
    if story.audio is None:
        story.audio = StoryAudio(object_key=key, content_type="audio/mpeg")
    else:
        story.audio.object_key = key
        story.audio.content_type = "audio/mpeg"
    story.status = "ready"
    _touch_progress(story, progress="ready", status="ready")
    story.error_message = None
    total_ms = int((time.perf_counter() - job_t0) * 1000)
    db_metrics = parse_metrics_json(story.metrics_json)
    base_metrics: dict[str, Any] = dict(prior_metrics or {})
    if not base_metrics:
        base_metrics = dict(db_metrics)
    else:
        # Keep DB stages from earlier attempts without re-adding llm_ms.
        base_metrics = {
            **db_metrics,
            **base_metrics,
            "stages": merge_stage_rows(
                db_metrics.get("stages"),
                base_metrics.get("stages"),
            ),
        }
        if base_metrics.get("llm_ms") is None and db_metrics.get("llm_ms") is not None:
            base_metrics["llm_ms"] = db_metrics["llm_ms"]
    merged = merge_job_metrics(
        base_metrics,
        llm_ms=llm_ms or base_metrics.get("llm_ms"),
        tts_ms=tts_ms,
        storage_ms=storage_ms,
        total_ms=total_ms,
    )
    stages = list(merged.get("stages") or [])
    if isinstance(stages, list):
        # Replace prior tts row if reclaim/resume re-ran speech.
        stages = [row for row in stages if not (
            isinstance(row, dict) and row.get("stage") == "tts"
        )]
        stages.append(
            {
                "stage": "tts",
                "ms": tts_ms,
                "provider": speech_name,
                "model": speech_model,
            }
        )
        merged["stages"] = stages
    story.metrics_json = json.dumps(merged, ensure_ascii=False)
    await db.commit()
    logger.info(
        "story_timing story_id=%s stage=job_total ok ms=%s llm_ms=%s tts_ms=%s storage_ms=%s audio_bytes=%s tokens=%s",
        story_id,
        total_ms,
        llm_ms or base_metrics.get("llm_ms"),
        tts_ms,
        storage_ms,
        len(audio_bytes),
        base_metrics.get("total_tokens"),
    )
    logger.info(
        "story_job ready story_id=%s audio_bytes=%s", story_id, len(audio_bytes)
    )


async def process_story_tts_resume(
    *,
    story_id: int,
    user_id: int,
    provider_voice_id: str,
    voice_settings: dict[str, Any],
    speech_provider: str | None,
    narration_body: str,
) -> None:
    """Resume after restart when LLM body already exists (skip LLM)."""
    job_t0 = time.perf_counter()
    async with SessionLocal() as db:
        try:
            speech_name = (
                speech_provider or first_configured_speech_provider()
            ).strip().lower()
            story = await db.get(Story, story_id)
            if story is None:
                return
            if story.status == "ready" and story.audio is not None:
                logger.info("story_tts_resume skip already_ready story_id=%s", story_id)
                return
            body = (narration_body or story.body or "").strip()
            if not body:
                raise RuntimeError("Cannot resume TTS: empty story body")
            story.status = "generating"
            story.error_message = None
            story.speech_provider = speech_name
            _touch_progress(story, progress="tts", status="generating")
            await db.commit()
            logger.info(
                "story_timing story_id=%s stage=tts_resume_start speech=%s body_chars=%s",
                story_id,
                speech_name,
                len(body),
            )
            await _run_tts_and_store(
                db,
                story_id=story_id,
                user_id=user_id,
                narration_body=body,
                provider_voice_id=provider_voice_id,
                voice_settings=voice_settings,
                speech_name=speech_name,
                job_t0=job_t0,
                llm_ms=0,
            )
        except Exception as exc:
            total_ms = int((time.perf_counter() - job_t0) * 1000)
            logger.exception(
                "story_tts_resume failed story_id=%s after_ms=%s", story_id, total_ms
            )
            try:
                await _set_story_progress(
                    db,
                    story_id,
                    progress="failed",
                    status="failed",
                    error_message=safe_error_message(
                        exc, fallback="Story TTS resume failed"
                    ),
                )
            except Exception:
                logger.exception(
                    "story_tts_resume failed to persist error story_id=%s", story_id
                )


async def process_story_job(
    *,
    story_id: int,
    request_data: dict[str, Any],
    provider_voice_id: str,
    voice_settings: dict[str, Any],
    user_id: int,
    episode_count: int,
    continuing_series_id: int | None,
    story_provider: str | None = None,
    speech_provider: str | None = None,
    resume_tts_only: bool = False,
) -> None:
    """Run outside the request lifecycle; opens its own DB session."""
    job_t0 = time.perf_counter()
    async with SessionLocal() as db:
        try:
            story = (
                await db.execute(
                    select(Story)
                    .where(Story.id == story_id)
                    .options(selectinload(Story.audio))
                )
            ).scalar_one_or_none()
            speech_name = (
                speech_provider or first_configured_speech_provider()
            ).strip().lower()
            # Prefer TTS-only when asked or when body was checkpointed at TTS.
            want_tts_only = resume_tts_only or (
                story is not None and should_resume_tts_only(story)
            )
            if want_tts_only and story is not None and (story.body or "").strip():
                logger.info(
                    "story_timing story_id=%s stage=tts_only_skip_llm body_chars=%s",
                    story_id,
                    len(story.body or ""),
                )
                story.status = "generating"
                story.error_message = None
                story.speech_provider = speech_name
                await db.commit()
                await _run_tts_and_store(
                    db,
                    story_id=story_id,
                    user_id=user_id,
                    narration_body=story.body,
                    provider_voice_id=provider_voice_id,
                    voice_settings=voice_settings,
                    speech_name=speech_name,
                    job_t0=job_t0,
                    llm_ms=0,
                )
                return

            await _set_story_progress(db, story_id, progress="queued", status="generating")
            req = deserialize_story_request(request_data)
            vs = VoiceSettings(**{
                k: voice_settings[k]
                for k in ("speed", "stability", "style", "similarity_boost")
                if k in voice_settings
            })

            story_name = (story_provider or await resolve_story_provider_name()).strip().lower()

            story = await db.get(Story, story_id)
            if story is not None:
                story.story_provider = story_name
                story.speech_provider = speech_name
                await db.commit()

            # Retry after draft failure: reuse checkpointed plan, skip plan LLM.
            if story is not None and should_resume_draft_only(story):
                saved_plan = load_episode_plan_json(story.episode_plan_json)
                if saved_plan is not None:
                    req.episode_plan = saved_plan
                    req.need_series_outline = False
                    logger.info(
                        "story_timing story_id=%s stage=draft_only_skip_plan title=%s",
                        story_id,
                        saved_plan.get("title"),
                    )

            # Silent story-element pick (gated; off during phase-1 clarity testing).
            from app.core.config import get_settings

            if (
                get_settings().feature_story_focus_elements
                and story is not None
                and not req.story_element
            ):
                reuse_id: str | None = None
                try:
                    params = json.loads(story.params_json or "{}")
                    if isinstance(params, dict):
                        raw_eid = params.get("story_element_id")
                        if isinstance(raw_eid, str) and raw_eid.strip():
                            reuse_id = raw_eid.strip()
                except json.JSONDecodeError:
                    params = {}
                child = await db.get(Child, story.child_id)
                element_payload = await resolve_story_element_for_job(
                    db,
                    child_id=story.child_id,
                    birth_date=child.birth_date if child else None,
                    salt=(child.nickname if child else "") or req.child_nickname or "",
                    episode_no=int(req.episode_no or story.episode_no or 1),
                    story_id=story_id,
                    reuse_element_id=reuse_id,
                )
                if element_payload:
                    req.story_element = element_payload
                    eid = element_payload["id"]
                    if reuse_id != eid:
                        try:
                            params = json.loads(story.params_json or "{}")
                        except json.JSONDecodeError:
                            params = {}
                        if not isinstance(params, dict):
                            params = {}
                        params["story_element_id"] = eid
                        story.params_json = json.dumps(params, ensure_ascii=False)
                        await db.commit()

            logger.info(
                "story_timing story_id=%s stage=job_start story=%s speech=%s duration_min=%s element=%s",
                story_id,
                story_name,
                speech_name,
                req.duration_minutes,
                (req.story_element or {}).get("id"),
            )

            async def on_progress(stage: str) -> None:
                await _set_story_progress(db, story_id, progress=stage)

            async def on_plan(plan: dict[str, Any]) -> None:
                """Checkpoint episode plan before draft so admin can inspect on failure."""
                story_row = await db.get(Story, story_id)
                if story_row is None:
                    return
                story_row.episode_plan_json = json.dumps(plan, ensure_ascii=False)
                title = str(plan.get("title") or "").strip()
                if title and not (story_row.title or "").strip():
                    story_row.title = title[:256]
                core = plan.get("core")
                if isinstance(core, str) and core.strip():
                    try:
                        params = json.loads(story_row.params_json or "{}")
                    except json.JSONDecodeError:
                        params = {}
                    if not isinstance(params, dict):
                        params = {}
                    params["core"] = core.strip()[:32]
                    story_row.params_json = json.dumps(params, ensure_ascii=False)
                await db.commit()

            provider = get_story_provider(story_name)
            llm_t0 = time.perf_counter()
            result = await provider.generate(
                req, on_progress=on_progress, on_plan=on_plan
            )
            llm_ms = int((time.perf_counter() - llm_t0) * 1000)
            logger.info(
                "story_timing story_id=%s stage=llm_total ok ms=%s body_chars=%s",
                story_id,
                llm_ms,
                len(result.body or ""),
            )

            story = await db.get(Story, story_id)
            if story is None:
                return

            story.title = result.title
            # Strip markers early so poll/UI never shows performance tags.
            story.body = strip_performance_markers(result.body)
            story.soft_hook = result.soft_hook
            story.error_message = None
            story.story_provider = story_name
            story.speech_provider = speech_name
            if result.episode_plan is not None:
                story.episode_plan_json = json.dumps(
                    result.episode_plan, ensure_ascii=False
                )
                # Mirror shape/theme/core into params for recent_history soft-dedup.
                try:
                    params = json.loads(story.params_json or "{}")
                except json.JSONDecodeError:
                    params = {}
                if not isinstance(params, dict):
                    params = {}
                from app.providers.story_prompt import history_fields_from_plan

                hist = history_fields_from_plan(result.episode_plan)
                if hist.get("story_shape"):
                    params["story_shape"] = hist["story_shape"]
                if "theme" in hist:
                    params["plan_theme"] = hist.get("theme")
                if hist.get("core_element"):
                    params["core_element"] = hist["core_element"]
                plan_core = result.episode_plan.get("core")
                if isinstance(plan_core, str) and plan_core.strip():
                    params["core"] = plan_core.strip()[:32]
                story.params_json = json.dumps(params, ensure_ascii=False)
            else:
                story.episode_plan_json = None
            merged_metrics = merge_metrics_dicts(
                parse_metrics_json(story.metrics_json),
                result.metrics,
                llm_ms=llm_ms,
            )
            story.metrics_json = json.dumps(merged_metrics, ensure_ascii=False)
            prompts_json = merge_submitted_prompts(story.prompts_json, result.prompts)
            if prompts_json:
                story.prompts_json = prompts_json
            llm_ms_total = int(merged_metrics.get("llm_ms") or llm_ms)

            if result.series_outline is not None:
                series = StorySeries(
                    user_id=user_id,
                    child_id=story.child_id,
                    title=result.series_title or result.title,
                    language=story.language,
                    theme=story.theme,
                    episode_count=clamp_episode_count(episode_count),
                    outline_json=json.dumps(result.series_outline, ensure_ascii=False),
                    status="active",
                )
                db.add(series)
                await db.flush()
                story.series_id = series.id
                story.episode_no = result.episode_no or 1
            elif continuing_series_id is not None:
                story.series_id = continuing_series_id
                story.episode_no = result.episode_no or story.episode_no
                series_row = await db.get(StorySeries, continuing_series_id)
                if series_row and story.episode_no and story.episode_no >= series_row.episode_count:
                    series_row.status = "completed"

            if story_tts_disabled():
                # Text-only mode: ready after LLM; do not checkpoint as tts.
                await db.commit()
                await _finalize_without_tts(
                    db,
                    story_id=story_id,
                    job_t0=job_t0,
                    llm_ms=llm_ms_total,
                    prior_metrics=merged_metrics,
                )
                return

            # Checkpoint body before TTS so restart can resume without re-LLM.
            _touch_progress(story, progress="tts", status="generating")
            await db.commit()

            await _run_tts_and_store(
                db,
                story_id=story_id,
                user_id=user_id,
                narration_body=result.body,
                provider_voice_id=provider_voice_id,
                voice_settings=vs.__dict__,
                speech_name=speech_name,
                job_t0=job_t0,
                llm_ms=llm_ms_total,
                prior_metrics=merged_metrics,
            )
        except Exception as exc:
            total_ms = int((time.perf_counter() - job_t0) * 1000)
            logger.exception(
                "story_job failed story_id=%s after_ms=%s", story_id, total_ms
            )
            try:
                failed = await db.get(Story, story_id)
                if failed is not None:
                    prompts_json = merge_submitted_prompts(
                        failed.prompts_json,
                        getattr(exc, "submitted_prompts", None),
                    )
                    if prompts_json:
                        failed.prompts_json = prompts_json
                    submitted_metrics = getattr(exc, "submitted_metrics", None)
                    if isinstance(submitted_metrics, dict) and submitted_metrics:
                        failed.metrics_json = json.dumps(
                            merge_metrics_dicts(
                                parse_metrics_json(failed.metrics_json),
                                submitted_metrics,
                            ),
                            ensure_ascii=False,
                        )
                    plan = getattr(exc, "submitted_episode_plan", None)
                    if isinstance(plan, dict) and not (failed.episode_plan_json or "").strip():
                        failed.episode_plan_json = json.dumps(plan, ensure_ascii=False)
                        title = str(plan.get("title") or "").strip()
                        if title and not (failed.title or "").strip():
                            failed.title = title[:256]
                await _set_story_progress(
                    db,
                    story_id,
                    progress="failed",
                    status="failed",
                    error_message=safe_error_message(exc, fallback="Story generation failed"),
                )
            except Exception:
                logger.exception("story_job failed to persist error story_id=%s", story_id)
