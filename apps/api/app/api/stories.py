import json
from collections.abc import AsyncIterator
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.db import get_db
from app.core.security import get_current_user
from app.services.auth_rate_limit import rate_limit_story_ip
from app.models.child import Child
from app.models.story import Story, StoryAudio
from app.models.story_series import StorySeries
from app.models.user import User
from app.models.voice import Voice, VoicePrefs
from app.providers.base import StoryRequest, VoiceSettings
from app.providers.factory import get_story_provider, get_tts_provider
from app.providers.story_prompt import (
    canonicalize_duration_minutes,
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
from app.services.llm_routing import ResolveContext, resolve_llm_choice_standalone
from app.services.provider_settings import (
    first_configured_speech_provider,
    resolve_speech_model,
    resolve_story_provider_name,
)
from app.services.storage import storage_service
from app.services.story_elements import resolve_story_element_for_job
from app.services.story_history import load_recent_story_history
from app.services.story_job_recovery import (
    TTS_LEASE_PROGRESS,
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
from app.services.theme_sparks import record_theme_spark_hint_use
from app.services.characters import (
    character_snapshot,
    load_characters_for_story,
    roster_entry,
)
from app.services.system_voice import ensure_system_voice, voice_accessible_to_user
from app.services.voice_settings import apply_voice_speed, resolve_voice_settings


router = APIRouter(prefix="/stories", tags=["stories"])

async def _resolve_roster(
    db: AsyncSession,
    *,
    user_id: int,
    body: StoryCreate,
    listener_child_id: int | None = None,
) -> tuple[list[dict], list[dict], list[int]]:
    """Load tonight characters → (roster prompt entries, snapshots, ids)."""
    rows = await load_characters_for_story(
        db,
        user_id=user_id,
        character_ids=list(body.character_ids or []),
        listener_child_id=listener_child_id,
    )
    related_ids = {
        int(r.related_child_id)
        for r in rows
        if r.kind == "child" and r.related_child_id is not None
    }
    children_by_id: dict[int, Child] = {}
    if related_ids:
        kids = (
            await db.execute(select(Child).where(Child.id.in_(related_ids)))
        ).scalars().all()
        children_by_id = {int(c.id): c for c in kids}
    roster: list[dict] = []
    snaps: list[dict] = []
    for r in rows:
        linked = None
        if r.kind == "child" and r.related_child_id is not None:
            linked = children_by_id.get(int(r.related_child_id))
        roster.append(roster_entry(r, child=linked))
        snaps.append(character_snapshot(r, child=linked))
    ids = [r.id for r in rows]
    return roster, snaps, ids


def _roster_from_snapshot(raw: object) -> list[dict] | None:
    """Rebuild prompt roster from persisted characters_snapshot."""
    if not isinstance(raw, list) or not raw:
        return None
    out: list[dict] = []
    for item in raw:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        entry: dict = {"name": name}
        desc = str(item.get("desc") or "").strip()
        if desc:
            entry["desc"] = desc
        age = item.get("age")
        if isinstance(age, int):
            entry["age"] = age
        elif isinstance(age, str) and age.strip().isdigit():
            entry["age"] = int(age.strip())
        gender = str(item.get("gender") or "").strip()
        if gender:
            entry["gender"] = gender
        out.append(entry)
    return out or None


def _normalize_audiences(body: StoryCreate, child: Child) -> list[dict]:
    """Build prompt audiences from request, falling back to primary child.

    Accepts canonical gender tokens (boy|girl|…) or legacy display labels;
    emits language-appropriate labels for the LLM (story language, not UI).
    """
    from app.services.child_profile import gender_label_for_language

    lang = (body.language or "zh").strip()
    prefer_sep = ", " if lang.lower().startswith("en") else "、"

    out: list[dict] = []
    for raw in body.audiences or []:
        name = (raw.name or "").strip()
        if not name:
            continue
        item: dict = {"name": name}
        if raw.age is not None:
            item["age"] = int(raw.age)
        g_label = gender_label_for_language(raw.gender, lang)
        if g_label:
            item["gender"] = g_label
        desc = (raw.desc or "").strip()
        if desc:
            item["desc"] = desc
        prefer = (raw.prefer or "").strip()
        if prefer:
            item["prefer"] = prefer
        out.append(item)
    if out:
        return out

    prefer_tags: list[str] = []
    if child.interests_json:
        try:
            parsed = json.loads(child.interests_json)
            if isinstance(parsed, list):
                prefer_tags = [str(x).strip() for x in parsed if str(x).strip()]
            elif isinstance(parsed, str) and parsed.strip():
                prefer_tags = [parsed.strip()]
        except json.JSONDecodeError:
            prefer_tags = []
    item = {
        "name": (child.nickname or "").strip() or "未命名",
        "age": age_years_int_on(child.birth_date),
    }
    g_label = gender_label_for_language(child.gender, lang)
    if g_label:
        item["gender"] = g_label
    intro = (child.intro or "").strip()
    if intro:
        item["desc"] = intro
    if prefer_tags:
        item["prefer"] = prefer_sep.join(prefer_tags)
    return [item]


async def _build_story_request(
    db: AsyncSession,
    *,
    child: Child,
    body: StoryCreate,
    audiences: list[dict] | None = None,
    episode_no: int = 1,
    series_outline: dict | None = None,
    need_series_outline: bool = False,
    recap: str | None = None,
    soft_series_mode: bool = False,
    preferred_kernel: str | None = None,
    exclude_story_id: int | None = None,
    roster: list[dict] | None = None,
) -> tuple[StoryRequest, str, str, str | None]:
    age_band = sync_age_band(child.birth_date)
    recent_history = await load_recent_story_history(
        db, child_id=child.id, exclude_story_id=exclude_story_id
    )
    from app.core.config import get_settings

    focus_id: str | None = None
    focus_label: str | None = None
    kernel_id: str | None = None
    if get_settings().feature_story_focus_elements:
        outline_focus, outline_how = focus_from_series_outline(
            series_outline, episode_no, age_band=age_band
        )
        focus_id, focus_label, kernel_id = await resolve_story_kernel_for_create(
            db,
            child_id=child.id,
            birth_date=child.birth_date,
            salt=child.nickname or "",
            episode_no=episode_no,
            preferred=preferred_kernel,
            outline_focus=outline_focus,
            outline_how=outline_how,
        )
    # Empty / placeholder theme → generic title (not focus/kernel label).
    theme = (body.theme or "").strip()
    theme_mode = (body.theme_mode or "seed").strip().lower()
    if theme_mode not in ("seed", "plot"):
        theme_mode = "seed"
    theme_source = (body.theme_source or "user").strip().lower()
    if theme_source not in ("user", "hint"):
        theme_source = "user"
    if not theme or theme in ("温柔的夜晚", "a gentle forest adventure"):
        theme = ((focus_label or focus_id) if focus_id else None) or "睡前小故事"
        theme = theme[:128]
        theme_mode = "seed"
        theme_source = "fallback"
    series_on = bool(soft_series_mode) or need_series_outline or series_outline is not None
    req = StoryRequest(
        child_nickname=child.nickname,
        age_band=age_band,
        language=body.language,
        theme=theme,
        theme_mode=theme_mode,
        theme_source=theme_source,
        duration_minutes=canonicalize_duration_minutes(body.duration_minutes),
        audiences=audiences or None,
        roster=roster or None,
        child_gender=normalize_gender(child.gender),
        child_age_years=age_years_int_on(child.birth_date),
        child_intro=(child.intro or "").strip() or None,
        recap=recap,
        soft_series_mode=series_on,
        development_focus=focus_id,
        development_focus_label=focus_label,
        wonder=body.wonder,
        dialogue=body.dialogue,
        episode_count=4,
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
    core: str | None = None
    if story.params_json:
        try:
            params = json.loads(story.params_json)
            if isinstance(params, dict):
                raw = (
                    params.get("core")
                    or params.get("development_focus_label")
                )
                if isinstance(raw, str) and raw.strip():
                    core = raw.strip()
        except json.JSONDecodeError:
            pass
    if not core and story.episode_plan_json:
        try:
            plan = json.loads(story.episode_plan_json)
            if isinstance(plan, dict):
                raw = plan.get("core")
                if isinstance(raw, str) and raw.strip():
                    core = raw.strip()
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
        core=core,
        story_provider=story.story_provider,
        story_model=getattr(story, "story_model", None),
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
    explicit_voice = voice_id is not None
    voice: Voice | None = None
    if chosen_id:
        voice = await db.get(Voice, chosen_id)
        if (
            voice is None
            or not voice_accessible_to_user(voice, user.id)
            or not bool(getattr(voice, "enabled", True))
        ):
            raise HTTPException(status_code=404, detail="Voice not found")
        if voice.kind == "clone" and not get_settings().feature_voice_clone:
            if explicit_voice:
                raise HTTPException(
                    status_code=403, detail="Voice clone is not available"
                )
            # Stale prefs pointing at a clone — fall back to system catalog.
            voice = await ensure_system_voice(db, user)
    else:
        voice = await ensure_system_voice(db, user)

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
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StoryOut:
    """Enqueue story generation; poll GET /stories/{id} until status ready|failed."""
    await rate_limit_story_ip(request)
    child = await db.get(Child, body.child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")

    voice, vs = await _resolve_voice_and_settings(db, user, child, body.voice_id)
    audiences = _normalize_audiences(body, child)
    roster, snaps, char_ids = await _resolve_roster(
        db, user_id=user.id, body=body, listener_child_id=child.id
    )
    story_req, focus_id, focus_label, kernel_id = await _build_story_request(
        db,
        child=child,
        body=body,
        audiences=audiences,
        roster=roster,
    )
    from app.core.config import get_settings
    from app.services.story_kernels import axis_for_focus

    params = body.model_dump(mode="json")
    params["theme"] = story_req.theme
    params["theme_mode"] = story_req.theme_mode
    params["theme_source"] = story_req.theme_source
    if body.theme_spark_id is not None:
        params["theme_spark_id"] = body.theme_spark_id
    params["audiences"] = audiences
    params["character_ids"] = char_ids
    params["characters_snapshot"] = snaps
    if get_settings().feature_story_focus_elements and focus_id:
        params["development_focus"] = focus_id
        params["development_focus_label"] = focus_label
        axis_id, _ = axis_for_focus(focus_id)
        params["story_axis"] = axis_id
        if kernel_id:
            params["story_kernel_id"] = kernel_id

    await check_and_increment(db, user.id, "story")

    story_provider = await resolve_story_provider_name()
    speech_provider = (
        voice.provider or first_configured_speech_provider()
    ).strip().lower()
    speech_model = await resolve_speech_model(
        speech_provider, voice_model=voice.speech_model
    )
    draft_choice = await resolve_llm_choice_standalone(
        ResolveContext(
            stage="story_draft",
            duration_minutes=story_req.duration_minutes,
            language=body.language,
            default_provider=story_provider,
        )
    )

    story = Story(
        user_id=user.id,
        child_id=child.id,
        voice_id=voice.id,
        language=body.language,
        theme=story_req.theme,
        duration_minutes=story_req.duration_minutes,
        status="generating",
        progress="queued",
        progress_at=datetime.now(timezone.utc),
        source="manual",
        memory_ids_json="[]",
        params_json=json.dumps(params, ensure_ascii=False),
        voice_settings_json=json.dumps(vs.__dict__),
        expires_at=story_expiry_from_now(user.story_retention_months),
        story_provider=story_provider,
        story_model=draft_choice.model or None,
        speech_provider=speech_provider,
        speech_model=speech_model or None,
    )
    db.add(story)
    await db.commit()
    await db.refresh(story)

    if story_req.theme_source == "hint":
        await record_theme_spark_hint_use(
            db,
            user_id=user.id,
            spark_id=body.theme_spark_id,
            theme=story_req.theme,
            language=body.language,
        )
        await db.commit()

    if kernel_id and get_settings().feature_story_focus_elements:
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
        episode_count=4,
        continuing_series_id=None,
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
    audiences = params.get("audiences") or []
    if not isinstance(audiences, list):
        audiences = []
    mode = params.get("theme_mode") or "seed"
    if mode not in ("seed", "plot"):
        mode = "seed"
    source = params.get("theme_source") or "user"
    # Retry must not re-claim hint/fallback as typed input; only user|hint are on StoryCreate.
    if source not in ("user", "hint"):
        source = "user"
    data = {
        "child_id": story.child_id,
        "theme": story.theme or params.get("theme") or "a gentle forest adventure",
        "theme_mode": mode,
        "theme_source": source,
        "language": story.language or params.get("language") or "zh",
        "duration_minutes": story.duration_minutes or params.get("duration_minutes") or 5,
        "voice_id": story.voice_id or params.get("voice_id"),
        "audiences": audiences,
        "character_ids": params.get("character_ids") or [],
        "wonder": params.get("wonder") or "soft",
        "dialogue": params.get("dialogue") or "some",
    }
    return StoryCreate.model_validate(data)


async def enqueue_story_retry(
    db: AsyncSession,
    *,
    story: Story,
    owner: User,
    background_tasks: BackgroundTasks,
    force_full: bool = False,
) -> Story:
    """Re-enqueue a failed/stuck story without charging quota.

    Shared by user and admin retry. Raises HTTPException on validation errors.
    When force_full is True, clears body/plan checkpoints and re-runs from the start.
    """
    if not is_retryable_story(story):
        raise HTTPException(
            status_code=400,
            detail="Only failed or stuck generating stories can be retried",
        )
    if story.child_id is None:
        raise HTTPException(status_code=400, detail="Missing child")
    if story.user_id != owner.id:
        raise HTTPException(status_code=404, detail="Story not found")

    if force_full:
        story.body = ""
        story.title = ""
        story.episode_plan_json = None
        story.soft_hook = None
        # Drop TTS checkpoint so we never resume audio-only after a forced full regen.
        if (story.progress or "") in ("tts", TTS_LEASE_PROGRESS):
            story.progress = "failed"

    resume_tts_only = (not force_full) and should_resume_tts_only(story)
    resume_draft_only = (
        (not force_full) and (not resume_tts_only) and should_resume_draft_only(story)
    )

    child = await db.get(Child, story.child_id)
    if child is None or child.user_id != owner.id:
        raise HTTPException(status_code=404, detail="Child not found")

    try:
        params = json.loads(story.params_json or "{}")
    except json.JSONDecodeError:
        params = {}
    body = _story_create_from_params(story, params if isinstance(params, dict) else {})

    series_row: StorySeries | None = None
    outline: dict | None = None
    episode_no = int(story.episode_no or params.get("episode_no") or 1)
    need_outline = False
    recap = story.recap
    soft_series = bool(story.series_id or params.get("soft_series_mode"))

    if story.series_id is not None:
        series_row = await db.get(StorySeries, story.series_id)
        if series_row is None or series_row.user_id != owner.id:
            raise HTTPException(status_code=404, detail="Series not found")
        try:
            outline = json.loads(series_row.outline_json or "{}")
        except json.JSONDecodeError as exc:
            raise HTTPException(status_code=500, detail="Series outline corrupt") from exc
        need_outline = False
    elif soft_series and not resume_draft_only:
        # Legacy soft-series first episode failed before a series row existed.
        need_outline = True
        episode_no = 1

    voice, vs = await _resolve_voice_and_settings(
        db, owner, child, story.voice_id or body.voice_id
    )
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

    audiences = _normalize_audiences(body, child)
    if isinstance(params, dict) and isinstance(params.get("audiences"), list) and params["audiences"]:
        audiences = params["audiences"]

    prev_kernel = None
    roster: list[dict] | None = None
    if isinstance(params, dict):
        raw_k = params.get("story_kernel_id")
        if isinstance(raw_k, str) and raw_k.strip():
            prev_kernel = raw_k.strip()
        roster = _roster_from_snapshot(params.get("characters_snapshot"))
    if roster is None:
        roster, _, _ = await _resolve_roster(
            db, user_id=owner.id, body=body, listener_child_id=child.id
        )
    story_req, focus_id, focus_label, kernel_id = await _build_story_request(
        db,
        child=child,
        body=body,
        audiences=audiences,
        episode_no=episode_no,
        series_outline=outline,
        need_series_outline=need_outline,
        recap=recap,
        soft_series_mode=soft_series or series_row is not None or need_outline,
        preferred_kernel=prev_kernel,
        exclude_story_id=story.id,
        roster=roster,
    )
    if resume_draft_only:
        saved_plan = load_episode_plan_json(story.episode_plan_json)
        if saved_plan is not None:
            story_req.episode_plan = saved_plan
            story_req.need_series_outline = False
    # Refresh params snapshot (keep voice/child binding on the story row).
    from app.services.story_kernels import axis_for_focus

    retry_params = body.model_dump(mode="json")
    retry_params["audiences"] = audiences
    retry_params["episode_no"] = episode_no
    if get_settings().feature_story_focus_elements:
        if focus_id:
            retry_params["development_focus"] = focus_id
            retry_params["development_focus_label"] = focus_label
            retry_params["story_axis"] = axis_for_focus(focus_id)[0]
        # Preserve element/kernel chosen on first attempt so retry does not re-pick.
        if isinstance(params, dict):
            prev_el = params.get("story_element_id")
            if isinstance(prev_el, str) and prev_el.strip():
                retry_params["story_element_id"] = prev_el.strip()
        if kernel_id or prev_kernel:
            retry_params["story_kernel_id"] = kernel_id or prev_kernel

    story_provider = await resolve_story_provider_name()
    speech_provider = (
        voice.provider or first_configured_speech_provider()
    ).strip().lower()
    speech_model = await resolve_speech_model(
        speech_provider, voice_model=voice.speech_model
    )
    duration_minutes = canonicalize_duration_minutes(story.duration_minutes)
    draft_choice = await resolve_llm_choice_standalone(
        ResolveContext(
            stage="story_draft",
            duration_minutes=duration_minutes,
            language=story.language,
            default_provider=story_provider,
        )
    )

    story.status = "generating"
    story.progress = "tts" if resume_tts_only else "queued"
    story.progress_at = datetime.now(timezone.utc)
    story.error_message = None
    story.voice_id = voice.id
    story.params_json = json.dumps(retry_params, ensure_ascii=False)
    story.voice_settings_json = json.dumps(vs.__dict__)
    story.story_provider = story_provider
    story.story_model = draft_choice.model or None
    story.duration_minutes = duration_minutes
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
        user_id=owner.id,
        episode_count=int(params.get("episode_count") or 4) if isinstance(params, dict) else 4,
        continuing_series_id=series_row.id if series_row else None,
        story_provider=story_provider,
        speech_provider=speech_provider,
        resume_tts_only=resume_tts_only,
    )

    return (
        await db.execute(
            select(Story).where(Story.id == story.id).options(selectinload(Story.audio))
        )
    ).scalar_one()


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
    story = await enqueue_story_retry(
        db,
        story=story,
        owner=user,
        background_tasks=background_tasks,
    )
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
        synth = await synthesize_with_prosody(
            tts,
            story.body or "",
            voice.provider_voice_id,
            vs,
            speech_provider=speech_provider,
            model=speech_model,
        )
        audio = synth.audio
        # Chunk for progressive transfer; full file already paced with pauses.
        step = 16_384
        for i in range(0, len(audio), step):
            yield audio[i : i + step]

    return StreamingResponse(gen(), media_type="audio/mpeg")


@router.post("/stream")
async def create_story_streaming(
    body: StoryCreate,
    request: Request,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """v0.2-ish: stream NDJSON events — text chunks then audio chunks (base64) for progressive UX."""
    import base64

    await rate_limit_story_ip(request)
    child = await db.get(Child, body.child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")
    voice, vs = await _resolve_voice_and_settings(db, user, child, body.voice_id)
    audiences = _normalize_audiences(body, child)
    roster, snaps, char_ids = await _resolve_roster(
        db, user_id=user.id, body=body, listener_child_id=child.id
    )
    story_req, focus_id, focus_label, kernel_id = await _build_story_request(
        db,
        child=child,
        body=body,
        audiences=audiences,
        roster=roster,
    )
    from app.core.config import get_settings
    from app.services.story_kernels import axis_for_focus

    params = body.model_dump(mode="json")
    params["theme"] = story_req.theme
    params["theme_mode"] = story_req.theme_mode
    params["theme_source"] = story_req.theme_source
    if body.theme_spark_id is not None:
        params["theme_spark_id"] = body.theme_spark_id
    params["audiences"] = audiences
    params["character_ids"] = char_ids
    params["characters_snapshot"] = snaps
    if get_settings().feature_story_focus_elements and focus_id:
        params["development_focus"] = focus_id
        params["development_focus_label"] = focus_label
        axis_id, _ = axis_for_focus(focus_id)
        params["story_axis"] = axis_id
        if kernel_id:
            params["story_kernel_id"] = kernel_id

    await check_and_increment(db, user.id, "story")

    story_name = await resolve_story_provider_name()
    speech_name = (voice.provider or first_configured_speech_provider()).strip().lower()
    speech_model = await resolve_speech_model(
        speech_name, voice_model=voice.speech_model
    )
    draft_choice = await resolve_llm_choice_standalone(
        ResolveContext(
            stage="story_draft",
            duration_minutes=story_req.duration_minutes,
            language=body.language,
            default_provider=story_name,
        )
    )

    story = Story(
        user_id=user.id,
        child_id=child.id,
        voice_id=voice.id,
        language=body.language,
        theme=story_req.theme,
        duration_minutes=story_req.duration_minutes,
        status="generating",
        progress="queued",
        progress_at=datetime.now(timezone.utc),
        source="manual",
        memory_ids_json="[]",
        params_json=json.dumps(params, ensure_ascii=False),
        voice_settings_json=json.dumps(vs.__dict__),
        expires_at=story_expiry_from_now(user.story_retention_months),
        story_provider=story_name,
        story_model=draft_choice.model or None,
        speech_provider=speech_name,
        speech_model=speech_model or None,
    )
    db.add(story)
    await db.commit()
    await db.refresh(story)

    if story_req.theme_source == "hint":
        await record_theme_spark_hint_use(
            db,
            user_id=user.id,
            spark_id=body.theme_spark_id,
            theme=story_req.theme,
            language=body.language,
        )
        await db.commit()

    if kernel_id and get_settings().feature_story_focus_elements:
        await record_kernel_usage(
            db, child_id=child.id, kernel_id=kernel_id, story_id=story.id
        )

    if get_settings().feature_story_focus_elements:
        element_payload = await resolve_story_element_for_job(
            db,
            child_id=child.id,
            birth_date=child.birth_date,
            salt=child.nickname or "",
            episode_no=1,
            story_id=story.id,
            reuse_element_id=None,
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
                    from app.services.llm_routing import draft_model_from_metrics

                    s.metrics_json = json.dumps(
                        merge_metrics_dicts(
                            parse_metrics_json(s.metrics_json),
                            result.metrics,
                        ),
                        ensure_ascii=False,
                    )
                    draft_mid = draft_model_from_metrics(result.metrics)
                    if draft_mid:
                        s.story_model = draft_mid
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
                        episode_count=4,
                        outline_json=json.dumps(result.series_outline, ensure_ascii=False),
                        status="active",
                    )
                    session.add(series)
                    await session.flush()
                    s.series_id = series.id
                    s.episode_no = result.episode_no or 1
                # Stay generating until audio is stored — never ready-before-audio.
                s.status = "generating"
                await session.commit()

        try:
            synth = await synthesize_with_prosody(
                tts,
                result.body,
                voice.provider_voice_id,
                vs,
                speech_provider=speech_name,
                model=speech_model,
            )
            audio_bytes = synth.audio
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
