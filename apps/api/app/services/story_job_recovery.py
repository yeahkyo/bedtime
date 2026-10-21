"""Reclaim orphaned in-process story jobs after API restart.

BackgroundTasks die with the process. On startup, reclaim rows whose progress
predates this process (or are hung past a stale threshold). Resume TTS when the
LLM body was checkpointed; otherwise mark failed for retry.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.story import Story
from app.models.voice import Voice
from app.providers.base import VoiceSettings
from app.services.provider_settings import first_configured_speech_provider

logger = logging.getLogger(__name__)

ORPHAN_FAIL_MESSAGE = (
    "Generation interrupted (server restart or worker lost). Please retry."
)

# Hung job inside the same process (TTS/LLM stuck without progress updates).
STALE_GENERATING_SECONDS = 300

# Lease marker while TTS is actively running (single-flight).
TTS_LEASE_PROGRESS = "tts_running"

# Active TTS can exceed 5 minutes; do not steal the lease until this long.
TTS_LEASE_STALE_SECONDS = 1800

_PROCESS_STARTED_AT: datetime | None = None


def mark_process_started(at: datetime | None = None) -> datetime:
    """Call once from API lifespan before reclaim."""
    global _PROCESS_STARTED_AT
    _PROCESS_STARTED_AT = at or datetime.now(timezone.utc)
    return _PROCESS_STARTED_AT


def process_started_at() -> datetime:
    global _PROCESS_STARTED_AT
    if _PROCESS_STARTED_AT is None:
        _PROCESS_STARTED_AT = datetime.now(timezone.utc)
    return _PROCESS_STARTED_AT


def _as_utc(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def is_generating_orphan(
    story: Story,
    *,
    now: datetime | None = None,
    started_at: datetime | None = None,
    stale_after: int = STALE_GENERATING_SECONDS,
) -> bool:
    """True if this generating row should be treated as abandoned.

    - progress_at before this process started → prior process died
    - progress_at missing → legacy / unsafe, treat as orphan
    - progress_at older than stale_after → hung in-process
    """
    if (story.status or "") != "generating":
        return False
    now = now or datetime.now(timezone.utc)
    started = _as_utc(started_at) or process_started_at()
    pa = _as_utc(story.progress_at)
    if pa is None:
        return True
    if pa < started:
        return True
    threshold = max(1, int(stale_after))
    if getattr(story, "progress", None) == TTS_LEASE_PROGRESS:
        threshold = max(threshold, TTS_LEASE_STALE_SECONDS)
    if (now - pa).total_seconds() >= threshold:
        return True
    return False


def is_retryable_story(
    story: Story,
    *,
    now: datetime | None = None,
) -> bool:
    """Failed always; generating only when orphaned/stale (not a live job)."""
    status = story.status or ""
    if status == "failed":
        return True
    if status == "generating":
        return is_generating_orphan(story, now=now)
    return False


def load_episode_plan_json(raw: str | None) -> dict[str, Any] | None:
    """Parse a saved episode_plan snapshot; None if missing/invalid."""
    if not (raw or "").strip():
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict) or not data:
        return None
    # Need beats + cast(s) so draft stage has something to land.
    beats = data.get("beats")
    casts = data.get("casts") if data.get("casts") is not None else data.get("cast")
    if not isinstance(beats, list) or not beats:
        return None
    if not isinstance(casts, list) or not casts:
        return None
    return data


def should_resume_tts_only(story: Story) -> bool:
    """Skip LLM only when body was checkpointed at the TTS stage and audio is missing."""
    if not (story.body or "").strip():
        return False
    if story.audio is not None and (story.audio.object_key or "").strip():
        return False
    return (story.progress or "") in ("tts", TTS_LEASE_PROGRESS)


def should_resume_draft_only(story: Story) -> bool:
    """Skip episode_plan LLM when a plan snapshot exists and body was never written."""
    if should_resume_tts_only(story):
        return False
    if (story.body or "").strip():
        return False
    return load_episode_plan_json(story.episode_plan_json) is not None


def can_resume_tts(story: Story) -> bool:
    """True when a reclaim/resume path may run TTS without re-LLM."""
    if (story.status or "") not in ("generating", "failed"):
        return False
    return should_resume_tts_only(story)


@dataclass
class ResumeTtsJob:
    story_id: int
    user_id: int
    provider_voice_id: str
    voice_settings: dict[str, Any]
    speech_provider: str
    narration_body: str


async def _voice_settings_from_story(story: Story) -> VoiceSettings:
    if story.voice_settings_json:
        try:
            saved = json.loads(story.voice_settings_json)
            if isinstance(saved, dict):
                return VoiceSettings(
                    **{
                        k: saved[k]
                        for k in ("speed", "stability", "style", "similarity_boost")
                        if k in saved
                    }
                )
        except (json.JSONDecodeError, TypeError):
            pass
    return VoiceSettings()


async def build_resume_tts_job(
    db: AsyncSession, story: Story
) -> ResumeTtsJob | None:
    if not can_resume_tts(story):
        return None
    if story.voice_id is None:
        return None
    voice = await db.get(Voice, story.voice_id)
    if voice is None or not (voice.provider_voice_id or "").strip():
        return None
    vs = await _voice_settings_from_story(story)
    speech = (
        story.speech_provider or voice.provider or first_configured_speech_provider()
    )
    return ResumeTtsJob(
        story_id=story.id,
        user_id=story.user_id,
        provider_voice_id=voice.provider_voice_id,
        voice_settings=vs.__dict__,
        speech_provider=speech.strip().lower(),
        narration_body=story.body,
    )


async def reclaim_orphaned_story_jobs(
    db: AsyncSession,
) -> tuple[list[ResumeTtsJob], int]:
    """Resume/fail only orphaned generating rows (not live jobs in this process)."""
    rows = (
        await db.execute(
            select(Story)
            .where(Story.status == "generating")
            .options(selectinload(Story.audio))
            .order_by(Story.id.asc())
        )
    ).scalars().all()
    if not rows:
        return [], 0

    to_resume: list[ResumeTtsJob] = []
    failed = 0
    now = datetime.now(timezone.utc)
    started = process_started_at()
    for story in rows:
        if not is_generating_orphan(story, now=now, started_at=started):
            logger.info(
                "story_reclaim skip_live story_id=%s progress=%s progress_at=%s",
                story.id,
                story.progress,
                story.progress_at,
            )
            continue
        job = await build_resume_tts_job(db, story)
        if job is not None:
            story.progress_at = now
            # Clear stale lease so resume can claim fresh.
            if (story.progress or "") == TTS_LEASE_PROGRESS:
                story.progress = "tts"
            to_resume.append(job)
            logger.info(
                "story_reclaim resume_tts story_id=%s body_chars=%s",
                story.id,
                len(job.narration_body),
            )
            continue
        prev_progress = story.progress
        story.status = "failed"
        story.progress = "failed"
        story.error_message = ORPHAN_FAIL_MESSAGE[:2000]
        story.progress_at = now
        failed += 1
        logger.warning(
            "story_reclaim mark_failed story_id=%s was_progress=%s body_chars=%s",
            story.id,
            prev_progress,
            len(story.body or ""),
        )
    await db.commit()
    return to_resume, failed


async def spawn_resumed_tts_jobs(jobs: list[ResumeTtsJob]) -> None:
    """Fire-and-forget TTS resume tasks (same process; better than leaving orphans)."""
    import asyncio

    from app.services.story_jobs import process_story_tts_resume, story_tts_disabled

    if story_tts_disabled():
        # Still resume: _run_tts_and_store finalizes as text_ready instead of hanging
        # orphans in generating/tts.
        logger.warning(
            "story_reclaim resume_as_text_ready count=%s (STORY_SKIP_TTS=1)",
            len(jobs),
        )

    for job in jobs:
        asyncio.create_task(
            process_story_tts_resume(
                story_id=job.story_id,
                user_id=job.user_id,
                provider_voice_id=job.provider_voice_id,
                voice_settings=job.voice_settings,
                speech_provider=job.speech_provider,
                narration_body=job.narration_body,
            ),
            name=f"story-tts-resume-{job.story_id}",
        )
