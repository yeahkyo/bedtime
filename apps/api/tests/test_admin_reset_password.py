"""Admin reset-password hashes new password and revokes sessions."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.api.admin.users import AdminUserDetailOut
from app.core.config import clear_settings_cache
from app.core.db import get_db
from app.core.security import require_admin
from app.services.passwords import verify_password


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


def _detail(user_id: int = 3) -> AdminUserDetailOut:
    return AdminUserDetailOut(
        id=user_id,
        display_name="Test",
        preferred_language="zh",
        apple_sub="phone:13800138000",
        phone="13800138000",
        disabled_at=None,
        token_version=1,
        created_at=None,
        deleted_at=None,
        story_retention_months=12,
        story_used=0,
        story_limit=30,
        clone_used=0,
        clone_limit=3,
        children=[],
        voices=[],
        stories_count=0,
    )


@pytest.mark.asyncio
async def test_admin_reset_password_ok_and_rejects_no_phone():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    phone_user = MagicMock()
    phone_user.id = 3
    phone_user.deleted_at = None
    phone_user.phone = "13800138000"
    phone_user.password_hash = "old-hash"

    apple_user = MagicMock()
    apple_user.id = 4
    apple_user.deleted_at = None
    apple_user.phone = None
    apple_user.password_hash = None

    class _Db:
        async def get(self, _model, user_id):
            if user_id == 3:
                return phone_user
            if user_id == 4:
                return apple_user
            return None

        async def commit(self):
            return None

    async def _db_override():
        yield _Db()

    async def _admin_override():
        return "admin"

    app.dependency_overrides[get_db] = _db_override
    app.dependency_overrides[require_admin] = _admin_override

    with patch(
        "app.api.admin.users.bump_token_version_and_revoke",
        AsyncMock(),
    ) as bump, patch(
        "app.api.admin.users.get_user",
        AsyncMock(return_value=_detail()),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            short = await client.post(
                "/admin/users/3/reset-password", json={"password": "short"}
            )
            assert short.status_code == 422

            ok = await client.post(
                "/admin/users/3/reset-password",
                json={"password": "new-secret-99"},
            )
            assert ok.status_code == 200
            assert ok.json()["id"] == 3
            assert phone_user.password_hash != "old-hash"
            assert verify_password("new-secret-99", phone_user.password_hash)
            bump.assert_awaited_once()

            no_phone = await client.post(
                "/admin/users/4/reset-password",
                json={"password": "new-secret-99"},
            )
            assert no_phone.status_code == 400

            missing = await client.post(
                "/admin/users/999/reset-password",
                json={"password": "new-secret-99"},
            )
            assert missing.status_code == 404
