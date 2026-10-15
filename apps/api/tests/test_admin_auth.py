from unittest.mock import patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.config import Settings, clear_settings_cache
from app.core.security import create_access_token, create_admin_token


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


def _app() -> FastAPI:
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")
    return app


@pytest.mark.asyncio
async def test_admin_login_requires_password():
    with patch(
        "app.api.admin.auth.get_settings",
        return_value=Settings(
            admin_bootstrap_username="admin",
            admin_bootstrap_password="",
        ),
    ):
        transport = ASGITransport(app=_app())
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/admin/auth/login", json={"username": "admin", "password": "x"}
            )
            assert res.status_code == 503


@pytest.mark.asyncio
async def test_admin_login_ok_and_rejects_wrong_password():
    settings = Settings(
        jwt_secret="test-secret",
        admin_bootstrap_username="admin",
        admin_bootstrap_password="secret-admin",
    )
    with patch("app.api.admin.auth.get_settings", return_value=settings), patch(
        "app.core.security.get_settings", return_value=settings
    ):
        transport = ASGITransport(app=_app())
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            bad = await client.post(
                "/admin/auth/login", json={"username": "admin", "password": "wrong"}
            )
            assert bad.status_code == 401

            ok = await client.post(
                "/admin/auth/login",
                json={"username": "admin", "password": "secret-admin"},
            )
            assert ok.status_code == 200
            body = ok.json()
            assert body["username"] == "admin"
            assert body["access_token"]

            denied = await client.get("/admin/users")
            assert denied.status_code == 401


def test_admin_token_not_valid_as_app_aud():
    settings = Settings(jwt_secret="test-secret")
    with patch("app.core.security.get_settings", return_value=settings):
        admin_tok, _ = create_admin_token("admin")
        app_tok = create_access_token("dev-parent")
    from jose import jwt

    admin_payload = jwt.get_unverified_claims(admin_tok)
    app_payload = jwt.get_unverified_claims(app_tok)
    assert admin_payload.get("aud") == "admin"
    assert app_payload.get("aud") == "app"
