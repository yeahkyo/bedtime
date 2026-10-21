"""Orphan story reclaim after process restart."""

from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.services.story_job_recovery import (
    ORPHAN_FAIL_MESSAGE,
    STALE_GENERATING_SECONDS,
    TTS_LEASE_PROGRESS,
    TTS_LEASE_STALE_SECONDS,
    can_resume_tts,
    is_generating_orphan,
    is_retryable_story,
    load_episode_plan_json,
    mark_process_started,
    reclaim_orphaned_story_jobs,
    should_resume_draft_only,
    should_resume_tts_only,
)


def test_should_resume_draft_only_when_plan_saved_without_body():
    plan = (
        '{"title":"夜","theme":"光","casts":[{"name":"豆豆","desc":"x"}],'
        '"beats":["a","b"],"shape":"一小圈"}'
    )
    ok = SimpleNamespace(
        status="failed",
        progress="failed",
        body="",
        episode_plan_json=plan,
        audio=None,
    )
    assert should_resume_draft_only(ok) is True
    assert load_episode_plan_json(plan)["title"] == "夜"

    # TTS checkpoint wins over draft-only.
    assert (
        should_resume_draft_only(
            SimpleNamespace(
                status="failed",
                progress="tts",
                body="正文已有",
                episode_plan_json=plan,
                audio=None,
            )
        )
        is False
    )
    assert (
        should_resume_draft_only(
            SimpleNamespace(
                status="failed",
                progress="failed",
                body="",
                episode_plan_json=None,
                audio=None,
            )
        )
        is False
    )
    assert load_episode_plan_json('{"title":"only"}') is None


def test_can_resume_tts_requires_tts_checkpoint_without_audio():
    ok = SimpleNamespace(
        status="generating",
        progress="tts",
        body="从前有座山",
        audio=None,
    )
    assert can_resume_tts(ok) is True
    assert should_resume_tts_only(ok) is True

    assert (
        can_resume_tts(
            SimpleNamespace(
                status="generating", progress="draft", body="x", audio=None
            )
        )
        is False
    )
    # Body alone is not enough — must be at TTS checkpoint.
    assert (
        should_resume_tts_only(
            SimpleNamespace(
                status="failed", progress="failed", body="x", audio=None
            )
        )
        is False
    )
    assert (
        can_resume_tts(
            SimpleNamespace(
                status="generating", progress="tts", body="", audio=None
            )
        )
        is False
    )
    assert (
        can_resume_tts(
            SimpleNamespace(
                status="generating",
                progress="tts",
                body="x",
                audio=SimpleNamespace(object_key="stories/1.mp3"),
            )
        )
        is False
    )
    # Failed after TTS keeps progress=tts → still resumeable.
    assert (
        can_resume_tts(
            SimpleNamespace(
                status="failed", progress="tts", body="x", audio=None
            )
        )
        is True
    )


def test_is_generating_orphan_uses_process_start_and_stale():
    started = datetime(2026, 1, 1, 12, 0, tzinfo=timezone.utc)
    mark_process_started(started)
    now = started + timedelta(seconds=60)

    live = SimpleNamespace(
        status="generating",
        progress_at=started + timedelta(seconds=10),
    )
    assert is_generating_orphan(live, now=now, started_at=started) is False
    assert is_retryable_story(live, now=now) is False

    prior = SimpleNamespace(
        status="generating",
        progress_at=started - timedelta(seconds=1),
    )
    assert is_generating_orphan(prior, now=now, started_at=started) is True

    hung = SimpleNamespace(
        status="generating",
        progress_at=now - timedelta(seconds=STALE_GENERATING_SECONDS + 1),
    )
    assert is_generating_orphan(hung, now=now, started_at=started) is True
    assert is_retryable_story(hung, now=now) is True

    missing = SimpleNamespace(status="generating", progress_at=None)
    assert is_generating_orphan(missing, now=now, started_at=started) is True

    failed = SimpleNamespace(status="failed", progress_at=now)
    assert is_retryable_story(failed, now=now) is True

    # Active TTS lease: past 5m but still within TTS lease grace (and after process start).
    lease_now = started + timedelta(seconds=STALE_GENERATING_SECONDS + 120)
    tts_lease = SimpleNamespace(
        status="generating",
        progress=TTS_LEASE_PROGRESS,
        progress_at=lease_now - timedelta(seconds=STALE_GENERATING_SECONDS + 10),
    )
    assert (
        is_generating_orphan(tts_lease, now=lease_now, started_at=started) is False
    )
    assert is_retryable_story(tts_lease, now=lease_now) is False

    tts_stale = SimpleNamespace(
        status="generating",
        progress=TTS_LEASE_PROGRESS,
        progress_at=lease_now - timedelta(seconds=TTS_LEASE_STALE_SECONDS + 1),
    )
    assert is_generating_orphan(tts_stale, now=lease_now, started_at=started) is True


@pytest.mark.asyncio
async def test_reclaim_skips_live_resumes_orphan_tts_fails_draft():
    # Process "started" slightly in the past so wall-clock now is after started.
    started = datetime.now(timezone.utc) - timedelta(seconds=60)
    mark_process_started(started)

    live_story = SimpleNamespace(
        id=38,
        status="generating",
        progress="draft",
        body="",
        audio=None,
        user_id=1,
        voice_id=2,
        speech_provider="fishaudio",
        voice_settings_json=None,
        progress_at=started + timedelta(seconds=5),
        error_message=None,
    )
    resume_story = SimpleNamespace(
        id=39,
        status="generating",
        progress="tts",
        body="正文已有",
        audio=None,
        user_id=1,
        voice_id=2,
        speech_provider="fishaudio",
        voice_settings_json='{"speed":1.0}',
        progress_at=started - timedelta(seconds=5),
        error_message=None,
    )
    draft_story = SimpleNamespace(
        id=40,
        status="generating",
        progress="draft",
        body="",
        audio=None,
        user_id=1,
        voice_id=2,
        speech_provider="fishaudio",
        voice_settings_json=None,
        progress_at=started - timedelta(seconds=5),
        error_message=None,
    )

    class _Scalars:
        def all(self):
            return [live_story, resume_story, draft_story]

    class _Result:
        def scalars(self):
            return _Scalars()

    voice = SimpleNamespace(provider_voice_id="v1", provider="fishaudio")

    class _Db:
        async def execute(self, _q):
            return _Result()

        async def get(self, model, pk):
            if pk == 2:
                return voice
            return None

        async def commit(self):
            return None

    with patch(
        "app.services.story_job_recovery.resolve_speech_provider_name",
        AsyncMock(return_value="fishaudio"),
    ):
        jobs, failed = await reclaim_orphaned_story_jobs(_Db())

    assert failed == 1
    assert len(jobs) == 1
    assert jobs[0].story_id == 39
    assert jobs[0].narration_body == "正文已有"
    assert draft_story.status == "failed"
    assert draft_story.error_message == ORPHAN_FAIL_MESSAGE
    assert resume_story.status == "generating"
    assert live_story.status == "generating"
    assert live_story.progress == "draft"
