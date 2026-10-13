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
