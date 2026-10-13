"""Background story generation: LLM pipeline + TTS, with DB progress updates."""

from __future__ import annotations

import json
import logging
from dataclasses import asdict, fields
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.db import SessionLocal
from app.models.story import Story, StoryAudio
from app.models.story_series import StorySeries
from app.providers.base import StoryRequest, VoiceSettings
from app.providers.factory import get_story_provider, get_tts_provider
from app.providers.story_prompt import clamp_episode_count
from app.services.errors import safe_error_message
from app.services.narration_prosody import strip_performance_markers, synthesize_with_prosody
from app.services.storage import storage_service

logger = logging.getLogger(__name__)

_STORY_REQ_KEYS = {f.name for f in fields(StoryRequest)}


def serialize_story_request(req: StoryRequest) -> dict[str, Any]:
    return asdict(req)


def deserialize_story_request(data: dict[str, Any]) -> StoryRequest:
    filtered = {k: data[k] for k in _STORY_REQ_KEYS if k in data}
    return StoryRequest(**filtered)


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
    story.progress = progress
    if status is not None:
        story.status = status
    if error_message is not None:
        story.error_message = error_message[:2000]
    await db.commit()


async def process_story_job(
    *,
    story_id: int,
    request_data: dict[str, Any],
    provider_voice_id: str,
    voice_settings: dict[str, Any],
    user_id: int,
    episode_count: int,
    continuing_series_id: int | None,
) -> None:
    """Run outside the request lifecycle; opens its own DB session."""
    async with SessionLocal() as db:
        try:
            await _set_story_progress(db, story_id, progress="queued", status="generating")
            req = deserialize_story_request(request_data)
            vs = VoiceSettings(**{
                k: voice_settings[k]
                for k in ("speed", "stability", "style", "similarity_boost")
                if k in voice_settings
            })

            async def on_progress(stage: str) -> None:
                await _set_story_progress(db, story_id, progress=stage)

            provider = get_story_provider()
            result = await provider.generate(req, on_progress=on_progress)

            story = await db.get(Story, story_id)
            if story is None:
                return

            story.title = result.title
            # Strip markers early so poll/UI never shows performance tags.
            story.body = strip_performance_markers(result.body)
            story.soft_hook = result.soft_hook
            story.error_message = None

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

            await db.commit()

            await _set_story_progress(db, story_id, progress="tts")
            tts = get_tts_provider()
            audio_bytes, display_body = await synthesize_with_prosody(
                tts, result.body, provider_voice_id, vs
            )
            story = await db.get(Story, story_id)
            if story is None:
                return
            # Persist marker-free body for reading UI; audio carries paced performance.
            story.body = display_body or result.body
            await db.commit()

            key = storage_service.new_key(f"stories/{user_id}", ".mp3")
            await storage_service.put_bytes(key, audio_bytes, "audio/mpeg")

            story = (
                await db.execute(
                    select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
                )
            ).scalar_one()
            if story.audio is None:
                story.audio = StoryAudio(object_key=key, content_type="audio/mpeg")
            else:
                story.audio.object_key = key
                story.audio.content_type = "audio/mpeg"
            story.status = "ready"
            story.progress = "ready"
            story.error_message = None
            await db.commit()
            logger.info(
                "story_job ready story_id=%s audio_bytes=%s", story_id, len(audio_bytes)
            )
        except Exception as exc:
            logger.exception("story_job failed story_id=%s", story_id)
            try:
                await _set_story_progress(
                    db,
                    story_id,
                    progress="failed",
                    status="failed",
                    error_message=safe_error_message(exc, fallback="Story generation failed"),
                )
            except Exception:
                logger.exception("story_job failed to persist error story_id=%s", story_id)
