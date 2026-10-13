import json
from collections.abc import AsyncIterator

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
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
    choose_development_focus,
    clamp_episode_count,
    focus_from_series_outline,
)
from app.schemas.common import StoryCreate, StoryOut
from app.services.errors import safe_error_message
from app.services.quota import check_and_increment
from app.services.retention import story_expiry_from_now
from app.services.narration_prosody import prepare_narration, synthesize_with_prosody
from app.services.storage import storage_service
from app.services.story_jobs import process_story_job, serialize_story_request
from app.services.voice_settings import resolve_voice_settings


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


def _build_story_request(
    *,
    child: Child,
    body: StoryCreate,
    interests: list,
    episode_no: int = 1,
    series_outline: dict | None = None,
    need_series_outline: bool = False,
    recap: str | None = None,
    soft_series_mode: bool | None = None,
) -> tuple[StoryRequest, str, str]:
    outline_focus, outline_how = focus_from_series_outline(
        series_outline, episode_no, age_band=child.age_band
    )
    if outline_focus:
        focus_id, focus_label = outline_focus, (outline_how or outline_focus)
    else:
        focus_id, focus_label = choose_development_focus(
            child.age_band,
            body.theme,
            preferred=body.development_focus or outline_focus,
            salt=child.nickname,
        )
        if outline_how and not body.development_focus:
            focus_label = outline_how
    series_on = soft_series_mode if soft_series_mode is not None else body.soft_series_mode
    req = StoryRequest(
        child_nickname=child.nickname,
        age_band=child.age_band,
        language=body.language,
        theme=body.theme,
        duration_minutes=body.duration_minutes,
        values=body.values,
        interests=interests,
        keywords=body.keywords,
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
    )
    return req, focus_id, focus_label


async def _story_out(db: AsyncSession, story: Story) -> StoryOut:
    audio_url = None
    if story.audio:
        audio_url = await storage_service.presigned_url(story.audio.object_key)
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
    )


async def _resolve_voice_and_settings(
    db: AsyncSession, user: User, child: Child, voice_id: int | None
) -> tuple[Voice, VoiceSettings]:
    settings = get_settings()
    prefs = (
        await db.execute(select(VoicePrefs).where(VoicePrefs.child_id == child.id))
    ).scalar_one_or_none()

    chosen_id = voice_id or (prefs.default_voice_id if prefs else None)
    voice: Voice | None = None
    if chosen_id:
        voice = await db.get(Voice, chosen_id)
        if voice is None or voice.user_id != user.id:
            raise HTTPException(status_code=404, detail="Voice not found")
    else:
        result = await db.execute(
            select(Voice).where(Voice.user_id == user.id, Voice.kind == "system").limit(1)
        )
        voice = result.scalar_one_or_none()
        if voice is None:
            if settings.provider_profile.lower() in ("volc", "doubao", "ark"):
                provider = "volc"
                voice_id = settings.volc_default_speaker
            else:
                provider = "elevenlabs"
                voice_id = settings.elevenlabs_default_voice_id
            voice = Voice(
                user_id=user.id,
                name="Gentle System",
                kind="system",
                provider=provider,
                provider_voice_id=voice_id,
                language="zh",
            )
            db.add(voice)
            await db.commit()
            await db.refresh(voice)

    if prefs:
        vs = VoiceSettings(
            speed=prefs.speed,
            stability=prefs.stability,
            style=prefs.style,
            similarity_boost=prefs.similarity_boost,
        )
    else:
        vs = resolve_voice_settings()
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
    story_req, focus_id, focus_label = _build_story_request(
        child=child,
        body=body,
        interests=interests,
        episode_no=episode_no,
        series_outline=outline,
        need_series_outline=need_outline,
        recap=recap,
        soft_series_mode=body.soft_series_mode or series_row is not None or need_outline,
    )
    params = body.model_dump()
    params["development_focus"] = focus_id
    params["development_focus_label"] = focus_label
    params["episode_no"] = episode_no

    await check_and_increment(db, user.id, "story")

    story = Story(
        user_id=user.id,
        child_id=child.id,
        voice_id=voice.id,
        language=body.language,
        theme=body.theme,
        duration_minutes=body.duration_minutes,
        status="generating",
        progress="queued",
        source=body.source,
        memory_ids_json=json.dumps(body.memory_ids),
        params_json=json.dumps(params, ensure_ascii=False),
        voice_settings_json=json.dumps(vs.__dict__),
        expires_at=story_expiry_from_now(user.story_retention_months),
        recap=recap,
        series_id=series_row.id if series_row else None,
        episode_no=episode_no if (series_row or need_outline) else None,
    )
    db.add(story)
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
    tts = get_tts_provider()

    async def gen() -> AsyncIterator[bytes]:
        audio, _display = await synthesize_with_prosody(
            tts, story.body or "", voice.provider_voice_id, vs
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
    story_req, focus_id, focus_label = _build_story_request(
        child=child,
        body=body,
        interests=interests,
        episode_no=episode_no,
        series_outline=outline,
        need_series_outline=need_outline,
        recap=recap,
        soft_series_mode=body.soft_series_mode or series_row is not None or need_outline,
    )
    params = body.model_dump()
    params["development_focus"] = focus_id
    params["development_focus_label"] = focus_label
    params["episode_no"] = episode_no

    await check_and_increment(db, user.id, "story")

    story = Story(
        user_id=user.id,
        child_id=child.id,
        voice_id=voice.id,
        language=body.language,
        theme=body.theme,
        duration_minutes=body.duration_minutes,
        status="generating",
        progress="queued",
        source=body.source,
        memory_ids_json=json.dumps(body.memory_ids),
        params_json=json.dumps(params, ensure_ascii=False),
        voice_settings_json=json.dumps(vs.__dict__),
        expires_at=story_expiry_from_now(user.story_retention_months),
        recap=recap,
        series_id=series_row.id if series_row else None,
        episode_no=episode_no if (series_row or need_outline) else None,
    )
    db.add(story)
    await db.commit()
    await db.refresh(story)

    story_id = story.id
    provider = get_story_provider()
    tts = get_tts_provider()

    async def _mark_failed(session, message: str) -> None:
        s = await session.get(Story, story_id)
        if s:
            s.status = "failed"
            s.progress = "failed"
            s.error_message = message[:2000]
            await session.commit()

    async def event_stream() -> AsyncIterator[bytes]:
        from app.core.db import SessionLocal

        try:
            result = await provider.generate(story_req)
        except Exception as exc:
            msg = safe_error_message(exc, fallback="Story generation failed")
            async with SessionLocal() as session:
                await _mark_failed(session, msg)
            err = json.dumps({"type": "error", "detail": msg}, ensure_ascii=False)
            yield (err + "\n").encode()
            return

        display_body = prepare_narration(
            result.body, voice_id=voice.provider_voice_id
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
                if result.series_outline is not None:
                    series = StorySeries(
                        user_id=user.id,
                        child_id=child.id,
                        title=result.series_title or result.title,
                        language=body.language,
                        theme=body.theme,
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
                tts, result.body, voice.provider_voice_id, vs
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
