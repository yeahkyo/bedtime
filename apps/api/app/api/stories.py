import json
from collections.abc import AsyncIterator
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.story import Story, StoryAudio
from app.models.story_series import StorySeries
from app.models.user import User
from app.models.voice import Voice, VoicePrefs
from app.providers.base import StoryRequest, VoiceSettings
from app.providers.factory import get_story_provider, get_tts_provider
from app.providers.story_prompt import (
    clamp_episode_count,
    focus_from_series_outline,
)
from app.schemas.common import StoryCreate, StoryOut
from app.services.errors import safe_error_message
from app.services.quota import check_and_increment
from app.services.retention import story_expiry_from_now
from app.services.child_profile import (
    age_years_int_on,
    normalize_gender,
    sync_age_band,
)
from app.services.narration_prosody import prepare_narration, synthesize_with_prosody
from app.services.provider_settings import (
    resolve_speech_model,
    resolve_speech_provider_name,
    resolve_story_provider_name,
)
from app.services.storage import storage_service
from app.services.story_elements import resolve_story_element_for_job
from app.services.story_history import load_recent_story_history
from app.services.story_job_recovery import (
    is_retryable_story,
    load_episode_plan_json,
    should_resume_draft_only,
    should_resume_tts_only,
)
from app.services.story_jobs import process_story_job, serialize_story_request
from app.services.story_kernels import (
    record_kernel_usage,
    resolve_story_kernel_for_create,
)
from app.services.system_voice import ensure_system_voice, voice_accessible_to_user
from app.services.voice_settings import apply_voice_speed, resolve_voice_settings


router = APIRouter(prefix="/stories", tags=["stories"])

# Style / cast knobs that should stay stable across a soft series.
_SERIES_INHERIT_KEYS = (
    "child_cast_role",
    "plot_drive",
    "imagery",
    "wonder",
    "wind_down",
    "dialogue",
    "lead_in",
    "keywords",
    "values",
    "episode_count",
    "duration_minutes",
)


async def _inherit_series_create_body(
    db: AsyncSession, series: StorySeries, body: StoryCreate
) -> StoryCreate:
    """When continuing a series, reuse episode-1 cast/dials so client defaults don't wipe them."""
    seed = (
        await db.execute(
            select(Story)
            .where(Story.series_id == series.id)
            .order_by(Story.episode_no.asc(), Story.id.asc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if seed is None or not seed.params_json:
        return body
    try:
        params = json.loads(seed.params_json)
    except json.JSONDecodeError:
        return body
    updates: dict = {}
    for key in _SERIES_INHERIT_KEYS:
        if key not in params or params[key] is None:
            continue
        updates[key] = params[key]
    if not updates:
        return body
    return body.model_copy(update=updates)


async def _resolve_series_state(
    db: AsyncSession, user: User, body: StoryCreate
) -> tuple[StorySeries | None, dict | None, int, str | None, bool]:
    """Returns (series_row, outline, episode_no, recap, need_outline)."""
    if body.series_id is not None:
        series = await db.get(StorySeries, body.series_id)
        if series is None or series.user_id != user.id:
            raise HTTPException(status_code=404, detail="Series not found")
        try:
            outline = json.loads(series.outline_json or "{}")
        except json.JSONDecodeError as exc:
            raise HTTPException(status_code=500, detail="Series outline corrupt") from exc
        max_ep = (
            await db.execute(
                select(Story.episode_no)
                .where(Story.series_id == series.id, Story.episode_no.is_not(None))
                .order_by(Story.episode_no.desc())
                .limit(1)
            )
        ).scalar_one_or_none()
        next_ep = int(max_ep or 0) + 1
        if next_ep > int(series.episode_count or 4):
            raise HTTPException(status_code=400, detail="Series already completed")
        recap = (body.recap or "").strip() or None
        if not recap:
            prev = (
                await db.execute(
                    select(Story)
                    .where(Story.series_id == series.id)
                    .order_by(Story.episode_no.desc())
                    .limit(1)
                )
            ).scalar_one_or_none()
            if prev and prev.soft_hook:
                recap = prev.soft_hook
        return series, outline, next_ep, recap, False

    if body.soft_series_mode:
        return None, None, 1, body.recap, True

    return None, None, 1, body.recap, False


async def _build_story_request(
    db: AsyncSession,
    *,
    child: Child,
    body: StoryCreate,
    interests: list,
    episode_no: int = 1,
    series_outline: dict | None = None,
    need_series_outline: bool = False,
    recap: str | None = None,
    soft_series_mode: bool | None = None,
    preferred_kernel: str | None = None,
    exclude_story_id: int | None = None,
) -> tuple[StoryRequest, str, str, str | None]:
    age_band = sync_age_band(child.birth_date)
    recent_history = await load_recent_story_history(
        db, child_id=child.id, exclude_story_id=exclude_story_id
    )
    outline_focus, outline_how = focus_from_series_outline(
        series_outline, episode_no, age_band=age_band
    )
    focus_id, focus_label, kernel_id = await resolve_story_kernel_for_create(
        db,
        child_id=child.id,
        birth_date=child.birth_date,
        salt=child.nickname or "",
        episode_no=episode_no,
        preferred=preferred_kernel or body.development_focus,
        outline_focus=outline_focus,
        outline_how=outline_how,
    )
    # Empty / placeholder theme → axis label only (not kernel name / soft_guidance).
    theme = (body.theme or "").strip()
    if not theme or theme in ("温柔的夜晚", "a gentle forest adventure"):
        theme = (focus_label or focus_id or "睡前小故事")[:128]
    series_on = soft_series_mode if soft_series_mode is not None else body.soft_series_mode
    req = StoryRequest(
        child_nickname=child.nickname,
        age_band=age_band,
        language=body.language,
        theme=theme,
        duration_minutes=body.duration_minutes,
        values=body.values,
        interests=interests,
        keywords=body.keywords,
        child_gender=normalize_gender(child.gender),
        child_age_years=age_years_int_on(child.birth_date),
        child_intro=(child.intro or "").strip() or None,
        recap=recap if recap is not None else body.recap,
        soft_series_mode=series_on or need_series_outline or series_outline is not None,
        development_focus=focus_id,
        development_focus_label=focus_label,
        child_cast_role=body.child_cast_role,
        plot_drive=body.plot_drive,
        imagery=body.imagery,
        wonder=body.wonder,
        wind_down=body.wind_down,
        dialogue=body.dialogue,
        lead_in=body.lead_in,
        episode_count=clamp_episode_count(body.episode_count),
        episode_no=episode_no,
        series_outline=series_outline,
        need_series_outline=need_series_outline,
        recent_history=recent_history,
    )
    return req, focus_id, focus_label, kernel_id


async def _story_out(db: AsyncSession, story: Story) -> StoryOut:
    audio_url = None
    if story.audio:
        audio_url = await storage_service.presigned_url(story.audio.object_key)
    voice_name: str | None = None
    if story.voice_id is not None:
        voice = await db.get(Voice, story.voice_id)
        if voice is not None:
            voice_name = voice.name
    focus_label: str | None = None
    if story.params_json:
        try:
            params = json.loads(story.params_json)
            if isinstance(params, dict):
                raw = params.get("development_focus_label") or params.get("development_focus")
                if isinstance(raw, str) and raw.strip():
                    focus_label = raw.strip()
        except json.JSONDecodeError:
            pass
    return StoryOut(
        id=story.id,
        title=story.title,
        language=story.language,
        theme=story.theme,
        body=story.body,
        status=story.status,
        source=story.source,
        soft_hook=story.soft_hook,
        audio_url=audio_url,
        duration_minutes=story.duration_minutes,
        series_id=story.series_id,
        episode_no=story.episode_no,
        child_id=story.child_id,
        progress=story.progress,
        error_message=story.error_message,
        voice_name=voice_name,
        development_focus_label=focus_label,
        story_provider=story.story_provider,
        speech_provider=story.speech_provider,
        speech_model=getattr(story, "speech_model", None),
    )


async def _resolve_voice_and_settings(
    db: AsyncSession, user: User, child: Child, voice_id: int | None
) -> tuple[Voice, VoiceSettings]:
    prefs = (
        await db.execute(select(VoicePrefs).where(VoicePrefs.child_id == child.id))
    ).scalar_one_or_none()

    chosen_id = voice_id or (prefs.default_voice_id if prefs else None)
    voice: Voice | None = None
    if chosen_id:
        voice = await db.get(Voice, chosen_id)
        if voice is None or not voice_accessible_to_user(voice, user.id):
            raise HTTPException(status_code=404, detail="Voice not found")
    else:
        speech = await resolve_speech_provider_name()
        voice = await ensure_system_voice(db, user, speech)

    if prefs:
        vs = VoiceSettings(
            speed=prefs.speed,
            stability=prefs.stability,
            style=prefs.style,
            similarity_boost=prefs.similarity_boost,
        )
    else:
        vs = resolve_voice_settings()
    # Voice catalog speed applies to all users; child prefs still supply tone knobs.
    vs = apply_voice_speed(vs, voice)
    return voice, vs


@router.get("", response_model=list[StoryOut])
async def list_stories(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[StoryOut]:
    rows = await db.execute(
        select(Story)
        .where(Story.user_id == user.id)
        .options(selectinload(Story.audio))
        .order_by(Story.id.desc())
    )
    return [await _story_out(db, s) for s in rows.scalars().all()]


@router.get("/{story_id}", response_model=StoryOut)
async def get_story(
    story_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> StoryOut:
    story = (
        await db.execute(
            select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
        )
    ).scalar_one_or_none()
    if story is None or story.user_id != user.id:
        raise HTTPException(status_code=404, detail="Story not found")
    return await _story_out(db, story)


@router.post("", response_model=StoryOut, status_code=202)
async def create_story_batch(
    body: StoryCreate,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StoryOut:
    """Enqueue story generation; poll GET /stories/{id} until status ready|failed."""
    child = await db.get(Child, body.child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")

    voice, vs = await _resolve_voice_and_settings(db, user, child, body.voice_id)
    interests = json.loads(child.interests_json) if child.interests_json else []
    series_row, outline, episode_no, recap, need_outline = await _resolve_series_state(
        db, user, body
    )
    if series_row is not None:
        body = await _inherit_series_create_body(db, series_row, body)
    story_req, focus_id, focus_label, kernel_id = await _build_story_request(
        db,
        child=child,
        body=body,
        interests=interests,
        episode_no=episode_no,
        series_outline=outline,
        need_series_outline=need_outline,
        recap=recap,
        soft_series_mode=body.soft_series_mode or series_row is not None or need_outline,
    )
    from app.services.story_kernels import axis_for_focus

    params = body.model_dump()
    params["theme"] = story_req.theme
    params["development_focus"] = focus_id
    # Axis label only (not soft_guidance / kernel name).
    params["development_focus_label"] = focus_label
    axis_id, _ = axis_for_focus(focus_id)
    params["story_axis"] = axis_id
    params["episode_no"] = episode_no
    if kernel_id:
        params["story_kernel_id"] = kernel_id

    await check_and_increment(db, user.id, "story")

    story_provider = await resolve_story_provider_name()
    speech_provider = (voice.provider or await resolve_speech_provider_name()).strip().lower()
    speech_model = await resolve_speech_model(
        speech_provider, voice_model=voice.speech_model
    )

    story = Story(
        user_id=user.id,
        child_id=child.id,
        voice_id=voice.id,
        language=body.language,
        theme=story_req.theme,
        duration_minutes=body.duration_minutes,
        status="generating",
        progress="queued",
        progress_at=datetime.now(timezone.utc),
        source=body.source,
        memory_ids_json=json.dumps(body.memory_ids),
        params_json=json.dumps(params, ensure_ascii=False),
        voice_settings_json=json.dumps(vs.__dict__),
        expires_at=story_expiry_from_now(user.story_retention_months),
        recap=recap,
        series_id=series_row.id if series_row else None,
        episode_no=episode_no if (series_row or need_outline) else None,
        story_provider=story_provider,
        speech_provider=speech_provider,
        speech_model=speech_model or None,
    )
    db.add(story)
    await db.commit()
    await db.refresh(story)

    if kernel_id:
        await record_kernel_usage(
            db, child_id=child.id, kernel_id=kernel_id, story_id=story.id
        )

    background_tasks.add_task(
        process_story_job,
        story_id=story.id,
        request_data=serialize_story_request(story_req),
        provider_voice_id=voice.provider_voice_id,
        voice_settings=vs.__dict__,
        user_id=user.id,
        episode_count=clamp_episode_count(body.episode_count),
        continuing_series_id=series_row.id if series_row else None,
        story_provider=story_provider,
        speech_provider=speech_provider,
    )

    story = (
        await db.execute(
            select(Story).where(Story.id == story.id).options(selectinload(Story.audio))
        )
    ).scalar_one()
    return await _story_out(db, story)


def _story_create_from_params(story: Story, params: dict) -> StoryCreate:
    """Rebuild StoryCreate from persisted params_json + story columns."""
    data = {
        "child_id": story.child_id,
        "theme": story.theme or params.get("theme") or "a gentle forest adventure",
        "language": story.language or params.get("language") or "zh",
        "duration_minutes": story.duration_minutes or params.get("duration_minutes") or 5,
        "voice_id": story.voice_id or params.get("voice_id"),
        "values": params.get("values") or [],
        "soft_series_mode": bool(params.get("soft_series_mode") or story.series_id),
        "recap": story.recap if story.recap is not None else params.get("recap"),
        "series_id": story.series_id or params.get("series_id"),
        "episode_count": params.get("episode_count") or 4,
        "source": story.source or params.get("source") or "manual",
        "memory_ids": params.get("memory_ids") or [],
        "keywords": params.get("keywords") or [],
        "development_focus": params.get("development_focus"),
        "story_element_id": params.get("story_element_id"),
        "child_cast_role": params.get("child_cast_role") or "auto",
        "plot_drive": params.get("plot_drive") or "light",
        "imagery": params.get("imagery") or "balanced",
        "wonder": params.get("wonder") or "soft",
        "wind_down": params.get("wind_down") or "gentle",
        "dialogue": params.get("dialogue") or "some",
        "lead_in": params.get("lead_in") or "soft",
    }
    return StoryCreate.model_validate(data)


@router.post("/{story_id}/retry", response_model=StoryOut, status_code=202)
async def retry_failed_story(
    story_id: int,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StoryOut:
    """Re-enqueue a failed or stuck generating story. Does not charge quota again.

    If body is already checkpointed and audio is missing, resumes TTS only.
    If episode_plan is checkpointed and body is empty, skips plan LLM and drafts only.
    """
    story = (
        await db.execute(
            select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
        )
    ).scalar_one_or_none()
    if story is None or story.user_id != user.id:
        raise HTTPException(status_code=404, detail="Story not found")
    if not is_retryable_story(story):
        raise HTTPException(
            status_code=400,
            detail="Only failed or stuck generating stories can be retried",
        )
    if story.child_id is None:
        raise HTTPException(status_code=400, detail="Missing child")
    resume_tts_only = should_resume_tts_only(story)
    resume_draft_only = (not resume_tts_only) and should_resume_draft_only(story)

    child = await db.get(Child, story.child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")

    try:
        params = json.loads(story.params_json or "{}")
    except json.JSONDecodeError:
        params = {}
    body = _story_create_from_params(story, params if isinstance(params, dict) else {})

    interests = json.loads(child.interests_json) if child.interests_json else []
    series_row: StorySeries | None = None
    outline: dict | None = None
    episode_no = int(story.episode_no or params.get("episode_no") or 1)
    need_outline = False
    recap = story.recap or body.recap

    if story.series_id is not None:
        series_row = await db.get(StorySeries, story.series_id)
        if series_row is None or series_row.user_id != user.id:
            raise HTTPException(status_code=404, detail="Series not found")
        try:
            outline = json.loads(series_row.outline_json or "{}")
        except json.JSONDecodeError as exc:
            raise HTTPException(status_code=500, detail="Series outline corrupt") from exc
        need_outline = False
    elif body.soft_series_mode and not resume_draft_only:
        # First episode failed before a series row was created — restart outline.
        # If we already have a saved episode_plan, skip outline+plan and draft only.
        need_outline = True
        episode_no = 1

    voice, vs = await _resolve_voice_and_settings(db, user, child, story.voice_id or body.voice_id)
    if story.voice_settings_json:
        try:
            saved = json.loads(story.voice_settings_json)
            if isinstance(saved, dict):
                vs = VoiceSettings(
                    **{
                        k: saved[k]
                        for k in ("speed", "stability", "style", "similarity_boost")
                        if k in saved
                    }
                )
        except (json.JSONDecodeError, TypeError):
            pass

    prev_kernel = None
    if isinstance(params, dict):
        raw_k = params.get("story_kernel_id")
        if isinstance(raw_k, str) and raw_k.strip():
            prev_kernel = raw_k.strip()
    story_req, focus_id, focus_label, kernel_id = await _build_story_request(
        db,
        child=child,
        body=body,
        interests=interests,
        episode_no=episode_no,
        series_outline=outline,
        need_series_outline=need_outline,
        recap=recap,
        soft_series_mode=body.soft_series_mode or series_row is not None or need_outline,
        preferred_kernel=prev_kernel,
        exclude_story_id=story.id,
    )
    if resume_draft_only:
        saved_plan = load_episode_plan_json(story.episode_plan_json)
        if saved_plan is not None:
            story_req.episode_plan = saved_plan
            story_req.need_series_outline = False
    # Refresh params snapshot (keep voice/child binding on the story row).
    from app.services.story_kernels import axis_for_focus

    retry_params = body.model_dump()
    retry_params["development_focus"] = focus_id
    retry_params["development_focus_label"] = focus_label
    retry_params["story_axis"] = axis_for_focus(focus_id)[0]
    retry_params["episode_no"] = episode_no
    # Preserve element/kernel chosen on first attempt so retry does not re-pick.
    if isinstance(params, dict):
        prev_el = params.get("story_element_id")
        if isinstance(prev_el, str) and prev_el.strip():
            retry_params["story_element_id"] = prev_el.strip()
    if kernel_id or prev_kernel:
        retry_params["story_kernel_id"] = kernel_id or prev_kernel

    story_provider = await resolve_story_provider_name()
    speech_provider = (voice.provider or await resolve_speech_provider_name()).strip().lower()
    speech_model = await resolve_speech_model(
        speech_provider, voice_model=voice.speech_model
    )

    story.status = "generating"
    story.progress = "tts" if resume_tts_only else "queued"
    story.progress_at = datetime.now(timezone.utc)
    story.error_message = None
    story.voice_id = voice.id
    story.params_json = json.dumps(retry_params, ensure_ascii=False)
    story.voice_settings_json = json.dumps(vs.__dict__)
    story.story_provider = story_provider
    story.speech_provider = speech_provider
    story.speech_model = speech_model or None
    await db.commit()
    await db.refresh(story)

    background_tasks.add_task(
        process_story_job,
        story_id=story.id,
        request_data=serialize_story_request(story_req),
        provider_voice_id=voice.provider_voice_id,
        voice_settings=vs.__dict__,
        user_id=user.id,
        episode_count=clamp_episode_count(body.episode_count),
        continuing_series_id=series_row.id if series_row else None,
        story_provider=story_provider,
        speech_provider=speech_provider,
        resume_tts_only=resume_tts_only,
    )

    story = (
        await db.execute(
            select(Story).where(Story.id == story.id).options(selectinload(Story.audio))
        )
    ).scalar_one()
    return await _story_out(db, story)


@router.post("/{story_id}/stream-audio")
async def stream_story_audio(
    story_id: int, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> StreamingResponse:
    """Re-stream stored audio if present; otherwise synthesize on the fly (counts as new TTS only if missing)."""
    story = (
        await db.execute(
            select(Story).where(Story.id == story_id).options(selectinload(Story.audio))
        )
    ).scalar_one_or_none()
    if story is None or story.user_id != user.id:
        raise HTTPException(status_code=404, detail="Story not found")

    if story.audio:
        # Prefer redirect-like URL consumption on client; for stream endpoint re-read from storage via regenerate path.
        # Clients should use audio_url for re-listen (zero TTS cost).
        raise HTTPException(
            status_code=400,
            detail="Audio already stored; use audio_url for free re-listen",
        )

    child = await db.get(Child, story.child_id) if story.child_id else None
    if child is None:
        raise HTTPException(status_code=400, detail="Missing child")
    voice, vs = await _resolve_voice_and_settings(db, user, child, story.voice_id)
    speech_provider = (voice.provider or story.speech_provider or "fishaudio").strip().lower()
    speech_model = await resolve_speech_model(
        speech_provider,
        voice_model=voice.speech_model or story.speech_model,
    )
    tts = get_tts_provider(speech_provider)

    async def gen() -> AsyncIterator[bytes]:
        audio, _display = await synthesize_with_prosody(
            tts,
            story.body or "",
            voice.provider_voice_id,
            vs,
            speech_provider=speech_provider,
            model=speech_model,
        )
        # Chunk for progressive transfer; full file already paced with pauses.
        step = 16_384
        for i in range(0, len(audio), step):
            yield audio[i : i + step]

    return StreamingResponse(gen(), media_type="audio/mpeg")


@router.post("/stream")
async def create_story_streaming(
    body: StoryCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> StreamingResponse:
    """v0.2-ish: stream NDJSON events — text chunks then audio chunks (base64) for progressive UX."""
    import base64

    child = await db.get(Child, body.child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")
    voice, vs = await _resolve_voice_and_settings(db, user, child, body.voice_id)
    interests = json.loads(child.interests_json) if child.interests_json else []
    series_row, outline, episode_no, recap, need_outline = await _resolve_series_state(
        db, user, body
    )
    if series_row is not None:
        body = await _inherit_series_create_body(db, series_row, body)
    story_req, focus_id, focus_label, kernel_id = await _build_story_request(
        db,
        child=child,
        body=body,
        interests=interests,
        episode_no=episode_no,
        series_outline=outline,
        need_series_outline=need_outline,
        recap=recap,
        soft_series_mode=body.soft_series_mode or series_row is not None or need_outline,
    )
    from app.services.story_kernels import axis_for_focus

    params = body.model_dump()
    params["theme"] = story_req.theme
    params["development_focus"] = focus_id
    params["development_focus_label"] = focus_label
    params["story_axis"] = axis_for_focus(focus_id)[0]
    params["episode_no"] = episode_no
    if kernel_id:
        params["story_kernel_id"] = kernel_id

    await check_and_increment(db, user.id, "story")

    story_name = await resolve_story_provider_name()
    speech_name = (voice.provider or await resolve_speech_provider_name()).strip().lower()
    speech_model = await resolve_speech_model(
        speech_name, voice_model=voice.speech_model
    )

    story = Story(
        user_id=user.id,
        child_id=child.id,
        voice_id=voice.id,
        language=body.language,
        theme=story_req.theme,
        duration_minutes=body.duration_minutes,
        status="generating",
        progress="queued",
        progress_at=datetime.now(timezone.utc),
        source=body.source,
        memory_ids_json=json.dumps(body.memory_ids),
        params_json=json.dumps(params, ensure_ascii=False),
        voice_settings_json=json.dumps(vs.__dict__),
        expires_at=story_expiry_from_now(user.story_retention_months),
        recap=recap,
        series_id=series_row.id if series_row else None,
        episode_no=episode_no if (series_row or need_outline) else None,
        story_provider=story_name,
        speech_provider=speech_name,
        speech_model=speech_model or None,
    )
    db.add(story)
    await db.commit()
    await db.refresh(story)

    if kernel_id:
        await record_kernel_usage(
            db, child_id=child.id, kernel_id=kernel_id, story_id=story.id
        )

    reuse_el = (body.story_element_id or "").strip() or None
    element_payload = await resolve_story_element_for_job(
        db,
        child_id=child.id,
        birth_date=child.birth_date,
        salt=child.nickname or "",
        episode_no=int(episode_no or 1),
        story_id=story.id,
        reuse_element_id=reuse_el,
    )
    if element_payload:
        story_req.story_element = element_payload
        params["story_element_id"] = element_payload["id"]
        story.params_json = json.dumps(params, ensure_ascii=False)
        await db.commit()

    story_id = story.id
    provider = get_story_provider(story_name)
    tts = get_tts_provider(speech_name)

    async def _mark_failed(
        session,
        message: str,
        prompts: list | None = None,
        episode_plan: dict | None = None,
        metrics: dict | None = None,
    ) -> None:
        from app.providers.chat_usage import merge_metrics_dicts, parse_metrics_json
        from app.providers.story_pipeline import merge_submitted_prompts

        s = await session.get(Story, story_id)
        if s is None:
            return
        if (s.status or "") == "ready":
            return
        # Keep TTS checkpoint so retry can skip LLM when body already exists.
        had_tts = (s.progress or "") in ("tts", "tts_running") and (s.body or "").strip()
        s.status = "failed"
        s.progress = "tts" if had_tts else "failed"
        s.error_message = message[:2000]
        prompts_json = merge_submitted_prompts(s.prompts_json, prompts)
        if prompts_json:
            s.prompts_json = prompts_json
        if isinstance(metrics, dict) and metrics:
            s.metrics_json = json.dumps(
                merge_metrics_dicts(parse_metrics_json(s.metrics_json), metrics),
                ensure_ascii=False,
            )
        if isinstance(episode_plan, dict) and not (s.episode_plan_json or "").strip():
            s.episode_plan_json = json.dumps(episode_plan, ensure_ascii=False)
            title = str(episode_plan.get("title") or "").strip()
            if title and not (s.title or "").strip():
                s.title = title[:256]
        await session.commit()

    async def event_stream() -> AsyncIterator[bytes]:
        from app.core.db import SessionLocal

        try:
            result = await provider.generate(story_req)
        except Exception as exc:
            msg = safe_error_message(exc, fallback="Story generation failed")
            async with SessionLocal() as session:
                await _mark_failed(
                    session,
                    msg,
                    getattr(exc, "submitted_prompts", None),
                    getattr(exc, "submitted_episode_plan", None),
                    getattr(exc, "submitted_metrics", None),
                )
            err = json.dumps({"type": "error", "detail": msg}, ensure_ascii=False)
            yield (err + "\n").encode()
            return

        display_body = prepare_narration(
            result.body,
            voice_id=voice.provider_voice_id,
            speech_provider=speech_name,
        ).display
        # Stream marker-free text in sentence-ish chunks for progressive UX.
        buf = ""
        for ch in display_body:
            buf += ch
            if ch in "。！？.!?\n" and buf.strip():
                payload = json.dumps(
                    {"type": "text", "story_id": story_id, "delta": buf}, ensure_ascii=False
                )
                yield (payload + "\n").encode()
                buf = ""
        if buf.strip():
            payload = json.dumps(
                {"type": "text", "story_id": story_id, "delta": buf}, ensure_ascii=False
            )
            yield (payload + "\n").encode()

        async with SessionLocal() as session:
            s = await session.get(Story, story_id)
            if s:
                s.body = display_body
                s.title = result.title
                s.soft_hook = result.soft_hook
                s.progress = "tts"
                if result.episode_plan is not None:
                    s.episode_plan_json = json.dumps(
                        result.episode_plan, ensure_ascii=False
                    )
                if result.metrics:
                    from app.providers.chat_usage import (
                        merge_metrics_dicts,
                        parse_metrics_json,
                    )

                    s.metrics_json = json.dumps(
                        merge_metrics_dicts(
                            parse_metrics_json(s.metrics_json),
                            result.metrics,
                        ),
                        ensure_ascii=False,
                    )
                from app.providers.story_pipeline import merge_submitted_prompts

                prompts_json = merge_submitted_prompts(s.prompts_json, result.prompts)
                if prompts_json:
                    s.prompts_json = prompts_json
                if result.series_outline is not None:
                    series = StorySeries(
                        user_id=user.id,
                        child_id=child.id,
                        title=result.series_title or result.title,
                        language=body.language,
                        theme=story_req.theme,
                        episode_count=clamp_episode_count(body.episode_count),
                        outline_json=json.dumps(result.series_outline, ensure_ascii=False),
                        status="active",
                    )
                    session.add(series)
                    await session.flush()
                    s.series_id = series.id
                    s.episode_no = result.episode_no or 1
                elif series_row is not None:
                    s.series_id = series_row.id
                    s.episode_no = result.episode_no or episode_no
                    ser = await session.get(StorySeries, series_row.id)
                    if ser and s.episode_no >= ser.episode_count:
                        ser.status = "completed"
                # Stay generating until audio is stored — never ready-before-audio.
                s.status = "generating"
                await session.commit()

        try:
            audio_bytes, _ = await synthesize_with_prosody(
                tts,
                result.body,
                voice.provider_voice_id,
                vs,
                speech_provider=speech_name,
                model=speech_model,
            )
            key = storage_service.new_key(f"stories/{user.id}", ".mp3")
            await storage_service.put_bytes(key, audio_bytes, "audio/mpeg")
        except Exception as exc:
            msg = safe_error_message(exc, fallback="Audio generation failed")
            async with SessionLocal() as session:
                await _mark_failed(session, msg)
            err = json.dumps({"type": "error", "detail": msg}, ensure_ascii=False)
            yield (err + "\n").encode()
            return

        step = 12_000
        for i in range(0, len(audio_bytes), step):
            chunk = audio_bytes[i : i + step]
            payload = json.dumps(
                {
                    "type": "audio",
                    "story_id": story_id,
                    "b64": base64.b64encode(chunk).decode(),
                }
            )
            yield (payload + "\n").encode()

        async with SessionLocal() as session:
            existing = (
                await session.execute(select(StoryAudio).where(StoryAudio.story_id == story_id))
            ).scalar_one_or_none()
            if existing is None:
                session.add(StoryAudio(story_id=story_id, object_key=key, content_type="audio/mpeg"))
            s = await session.get(Story, story_id)
            if s:
                s.status = "ready"
                s.progress = "ready"
                s.error_message = None
            await session.commit()

        url = await storage_service.presigned_url(key)
        async with SessionLocal() as session:
            s = await session.get(Story, story_id)
            sid = s.series_id if s else None
            eno = s.episode_no if s else result.episode_no
        done = json.dumps(
            {
                "type": "done",
                "story_id": story_id,
                "audio_url": url,
                "body": display_body,
                "series_id": sid,
                "episode_no": eno,
            },
            ensure_ascii=False,
        )
        yield (done + "\n").encode()

    return StreamingResponse(event_stream(), media_type="application/x-ndjson")
