"""Ensure story create validates ownership before charging quota."""

import inspect

from app.api import stories


def test_batch_create_checks_child_before_quota():
    source = inspect.getsource(stories.create_story_batch)
    child_pos = source.index("await db.get(Child")
    quota_pos = source.index("await check_and_increment")
    assert child_pos < quota_pos


def test_stream_create_checks_child_before_quota():
    source = inspect.getsource(stories.create_story_streaming)
    child_pos = source.index("await db.get(Child")
    quota_pos = source.index("await check_and_increment")
    assert child_pos < quota_pos


def test_retry_failed_story_does_not_charge_quota():
    source = inspect.getsource(stories.retry_failed_story)
    assert "check_and_increment" not in source
    assert "failed" in source and "generating" in source
    assert "resume_tts_only" in source
    assert "resume_draft_only" in source
    assert "should_resume_draft_only" in source
