"""Unit tests for throttled last_active_at touch."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.last_active import TOUCH_INTERVAL, touch_user_last_active


@pytest.mark.asyncio
async def test_touch_writes_when_null():
    db = AsyncMock()
    user = MagicMock()
    user.last_active_at = None

    assert await touch_user_last_active(db, user) is True
    assert user.last_active_at is not None
    db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_touch_skips_within_interval():
    db = AsyncMock()
    user = MagicMock()
    user.last_active_at = datetime.now(timezone.utc) - timedelta(minutes=1)

    assert await touch_user_last_active(db, user) is False
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_touch_writes_after_interval():
    db = AsyncMock()
    user = MagicMock()
    user.last_active_at = datetime.now(timezone.utc) - TOUCH_INTERVAL - timedelta(seconds=1)

    assert await touch_user_last_active(db, user) is True
    db.commit.assert_awaited_once()
