"""DELETE /v1/children/{id} ownership and response."""

from unittest.mock import MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api import children
from app.core.config import Settings, clear_settings_cache
from app.core.security import create_access_token
from app.models.child import Child
from app.models.user import User


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


def _app() -> FastAPI:
    app = FastAPI()
    app.include_router(children.router, prefix="/v1")
    return app


@pytest.mark.asyncio
async def test_delete_child_ok_and_foreign_denied():
    settings = Settings(jwt_secret="test-secret", jwt_access_expire_minutes=60)
    owner = User(id=1, apple_sub="phone:13800138000", token_version=0, preferred_language="zh")
    child = Child(id=10, user_id=1, nickname="豆豆", age_band="3-5", gender="unspecified")
    deleted: list[object] = []

    class Sess:
        async def get(self, model, pk):
            if model is Child and pk == 10:
                return child
            return None

        async def delete(self, obj):
            deleted.append(obj)

        async def commit(self):
            pass

        async def execute(self, stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = owner
            return result

    db = Sess()

    async def override_db():
        yield db

    app = _app()
    from app.core.db import get_db

    app.dependency_overrides[get_db] = override_db

    with patch("app.core.security.get_settings", return_value=settings):
        tok = create_access_token(owner.apple_sub, token_version=0)
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            ok = await client.delete(
                "/v1/children/10", headers={"Authorization": f"Bearer {tok}"}
            )
            assert ok.status_code == 200, ok.text
            assert ok.json()["ok"] is True
            assert deleted == [child]

            missing = await client.delete(
                "/v1/children/99", headers={"Authorization": f"Bearer {tok}"}
            )
            assert missing.status_code == 404


@pytest.mark.asyncio
async def test_delete_child_wrong_owner():
    settings = Settings(jwt_secret="test-secret", jwt_access_expire_minutes=60)
    user = User(id=2, apple_sub="phone:13900000000", token_version=0, preferred_language="zh")
    child = Child(id=10, user_id=1, nickname="别人的", age_band="3-5", gender="unspecified")

    class Sess:
        async def get(self, model, pk):
            if model is Child and pk == 10:
                return child
            return None

        async def execute(self, stmt):
            result = MagicMock()
            result.scalar_one_or_none.return_value = user
            return result

    db = Sess()

    async def override_db():
        yield db

    app = _app()
    from app.core.db import get_db

    app.dependency_overrides[get_db] = override_db

    with patch("app.core.security.get_settings", return_value=settings):
        tok = create_access_token(user.apple_sub, token_version=0)
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.delete(
                "/v1/children/10", headers={"Authorization": f"Bearer {tok}"}
            )
            assert res.status_code == 404
