from unittest.mock import AsyncMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api import account
from app.core.config import Settings, clear_settings_cache


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


def _app() -> FastAPI:
    app = FastAPI()
    app.include_router(account.router, prefix="/v1")
    return app


@pytest.mark.asyncio
async def test_retention_non_dev_requires_admin_token():
    with patch("app.api.account.get_settings", return_value=Settings(
        env="prod",
        jwt_secret="prod-secret",
        dev_auth_bypass=False,
        retention_admin_token="secret-admin",
    )), patch(
        "app.api.account.purge_expired_raw_voices", new_callable=AsyncMock, return_value=0
    ), patch(
        "app.api.account.purge_expired_stories", new_callable=AsyncMock, return_value=0
    ):
        transport = ASGITransport(app=_app())
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            denied = await client.post("/v1/account/retention/run")
            assert denied.status_code == 403

            ok = await client.post(
                "/v1/account/retention/run",
                headers={"X-Retention-Admin-Token": "secret-admin"},
            )
            assert ok.status_code == 200
            assert ok.json()["purged_raw_voices"] == 0


@pytest.mark.asyncio
async def test_retention_dev_accepts_admin_token_without_user():
    """Staging hosts often keep ENV=dev for App dev-login; cron still uses admin token."""
    with patch("app.api.account.get_settings", return_value=Settings(
        env="dev",
        jwt_secret="dev-secret",
        dev_auth_bypass=True,
        retention_admin_token="secret-admin",
    )), patch(
        "app.api.account.purge_expired_raw_voices", new_callable=AsyncMock, return_value=1
    ), patch(
        "app.api.account.purge_expired_stories", new_callable=AsyncMock, return_value=2
    ):
        transport = ASGITransport(app=_app())
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            ok = await client.post(
                "/v1/account/retention/run",
                headers={"X-Retention-Admin-Token": "secret-admin"},
            )
            assert ok.status_code == 200
            body = ok.json()
            assert body["purged_raw_voices"] == 1
            assert body["purged_stories"] == 2
            assert body["requested_by"] is None
