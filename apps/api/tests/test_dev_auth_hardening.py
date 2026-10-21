"""Anonymous bypass vs explicit /dev-login (staging-safe split)."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException

from app.core.config import Settings, clear_settings_cache
from app.core.security import get_current_user


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


@pytest.mark.asyncio
async def test_anonymous_rejected_when_bypass_off_even_in_dev():
    settings = Settings(env="dev", dev_auth_bypass=False)
    db = AsyncMock()
    with patch("app.core.security.get_settings", return_value=settings):
        with pytest.raises(HTTPException) as exc:
            await get_current_user(credentials=None, db=db)
    assert exc.value.status_code == 401


@pytest.mark.asyncio
async def test_anonymous_impersonates_when_bypass_on():
    settings = Settings(env="dev", dev_auth_bypass=True)
    user = MagicMock()
    result = MagicMock()
    result.scalar_one_or_none.return_value = user
    db = AsyncMock()
    db.execute = AsyncMock(return_value=result)
    with patch("app.core.security.get_settings", return_value=settings):
        got = await get_current_user(credentials=None, db=db)
    assert got is user
