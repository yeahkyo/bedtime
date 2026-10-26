"""Invite register, password login, refresh rotation / reuse, account delete gate."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient
from jose import jwt

from app.api import account, auth
from app.core.config import Settings, clear_settings_cache
from app.core.security import create_access_token, get_current_user
from app.models.invite import InviteCode
from app.models.refresh_token import RefreshToken
from app.models.user import User
from app.services.passwords import hash_password, verify_password
from app.services.phone import normalize_phone
from app.services.refresh_tokens import hash_refresh_token


@pytest.fixture(autouse=True)
def _clear_settings():
    clear_settings_cache()
    yield
    clear_settings_cache()


def test_password_hash_roundtrip():
    h = hash_password("secret-pass-1")
    assert h != "secret-pass-1"
    assert verify_password("secret-pass-1", h)
    assert not verify_password("wrong", h)


def test_normalize_phone():
    assert normalize_phone("13800138000") == "13800138000"
    assert normalize_phone("+86 138-0013-8000") == "13800138000"
    assert normalize_phone("01234567890") == "01234567890"  # App Review allowlist
    with pytest.raises(HTTPException):
        normalize_phone("123")


def test_access_token_has_ver_and_short_exp():
    settings = Settings(jwt_secret="test-secret", jwt_access_expire_minutes=60)
    with patch("app.core.security.get_settings", return_value=settings):
        tok = create_access_token("phone:13800138000", token_version=3)
        payload = jwt.get_unverified_claims(tok)
    assert payload["ver"] == 3
    assert payload["aud"] == "app"
    exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
    assert exp - datetime.now(timezone.utc) < timedelta(hours=2)


@pytest.mark.asyncio
async def test_token_version_mismatch_rejected():
    settings = Settings(jwt_secret="test-secret", jwt_access_expire_minutes=60)
    with patch("app.core.security.get_settings", return_value=settings):
        tok = create_access_token("phone:13800138000", token_version=1)
    user = User(
        id=1,
        apple_sub="phone:13800138000",
        phone="13800138000",
        token_version=2,
        preferred_language="zh",
    )
    result = MagicMock()
    result.scalar_one_or_none.return_value = user
    db = AsyncMock()
    db.execute = AsyncMock(return_value=result)
    creds = MagicMock()
    creds.credentials = tok
    with patch("app.core.security.get_settings", return_value=settings):
        with pytest.raises(HTTPException) as exc:
            await get_current_user(credentials=creds, db=db)
    assert exc.value.status_code == 401


def _auth_app() -> FastAPI:
    app = FastAPI()
    app.include_router(auth.router, prefix="/v1")
    app.include_router(account.router, prefix="/v1")
    return app


@pytest.mark.asyncio
async def test_dev_login_disabled_outside_dev():
    settings = Settings(env="staging", jwt_secret="x" * 20, dev_auth_bypass=False)
    with patch("app.api.auth.get_settings", return_value=settings):
        transport = ASGITransport(app=_auth_app())
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/auth/dev-login",
                json={"display_name": "Dev", "preferred_language": "zh"},
            )
            assert res.status_code == 403


@pytest.mark.asyncio
async def test_delete_account_disabled_outside_dev():
    settings = Settings(env="staging", jwt_secret="test-secret", jwt_access_expire_minutes=60)
    user = User(
        id=1,
        apple_sub="phone:13800138000",
        phone="13800138000",
        token_version=0,
        preferred_language="zh",
    )
    with patch("app.core.security.get_settings", return_value=settings):
        tok = create_access_token(user.apple_sub, token_version=0)

    result = MagicMock()
    result.scalar_one_or_none.return_value = user
    db = AsyncMock()
    db.execute = AsyncMock(return_value=result)

    async def override_db():
        yield db

    app = _auth_app()
    from app.core.db import get_db

    app.dependency_overrides[get_db] = override_db
    with patch("app.api.account.get_settings", return_value=settings), patch(
        "app.core.security.get_settings", return_value=settings
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.delete(
                "/v1/account", headers={"Authorization": f"Bearer {tok}"}
            )
            assert res.status_code == 403
            assert "disabled" in res.json()["detail"].lower()


@pytest.mark.asyncio
async def test_register_login_refresh_flow_mocked():
    settings = Settings(
        env="dev",
        jwt_secret="test-secret",
        jwt_access_expire_minutes=60,
        jwt_refresh_expire_days=7,
    )
    now = datetime.now(timezone.utc)
    invite = InviteCode(
        id=1,
        code="LULL-TESTCODE",
        created_at=now,
        expires_at=now + timedelta(days=7),
    )
    created_user: dict = {}

    class Sess:
        def __init__(self):
            self._users_by_phone: dict = {}
            self._refresh: dict = {}
            self._invites = {invite.code: invite}
            self.commit_count = 0

        async def execute(self, stmt):
            result = MagicMock()
            sql = str(stmt).lower()
            compiled = stmt.compile()
            params = dict(compiled.params)
            if "invite_codes" in sql:
                code = None
                for v in params.values():
                    if isinstance(v, str) and v.startswith("LULL"):
                        code = v
                result.scalar_one_or_none.return_value = self._invites.get(code)
                return result
            if "users" in sql:
                phone = None
                sub = None
                for v in params.values():
                    if isinstance(v, str) and v.startswith("1") and len(v) == 11:
                        phone = v
                    if isinstance(v, str) and v.startswith("phone:"):
                        sub = v
                if phone:
                    result.scalar_one_or_none.return_value = self._users_by_phone.get(phone)
                elif sub:
                    u = next(
                        (x for x in self._users_by_phone.values() if x.apple_sub == sub),
                        None,
                    )
                    result.scalar_one_or_none.return_value = u
                else:
                    result.scalar_one_or_none.return_value = None
                return result
            if "refresh_tokens" in sql:
                th = None
                for v in params.values():
                    if isinstance(v, str) and len(v) == 64:
                        th = v
                result.scalar_one_or_none.return_value = self._refresh.get(th)
                return result
            result.scalar_one_or_none.return_value = None
            return result

        def add(self, obj):
            if isinstance(obj, User):
                obj.id = 42
                self._users_by_phone[obj.phone] = obj
                created_user["u"] = obj
            if isinstance(obj, RefreshToken):
                obj.id = len(self._refresh) + 1
                self._refresh[obj.token_hash] = obj

        async def flush(self):
            pass

        async def commit(self):
            self.commit_count += 1

        async def get(self, model, pk):
            if model is User and created_user.get("u") and created_user["u"].id == pk:
                return created_user["u"]
            return None

    db = Sess()

    async def override_db():
        yield db

    fake_redis = AsyncMock()
    fake_redis.incr = AsyncMock(return_value=1)
    fake_redis.expire = AsyncMock()

    async def revoke_all(db_arg, user_id):
        now2 = datetime.now(timezone.utc)
        for row in db._refresh.values():
            if row.user_id == user_id and row.revoked_at is None:
                row.revoked_at = now2
        return 1

    app = _auth_app()
    from app.core.db import get_db

    app.dependency_overrides[get_db] = override_db

    with patch("app.api.auth.get_settings", return_value=settings), patch(
        "app.core.security.get_settings", return_value=settings
    ), patch(
        "app.services.refresh_tokens.get_settings", return_value=settings
    ), patch(
        "app.services.auth_rate_limit.get_redis", AsyncMock(return_value=fake_redis)
    ), patch(
        "app.services.refresh_tokens.revoke_all_refresh",
        side_effect=revoke_all,
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            reg = await client.post(
                "/v1/auth/register",
                json={
                    "invite_code": "LULL-TESTCODE",
                    "phone": "13800138000",
                    "password": "password1",
                    "display_name": "Tester",
                },
            )
            assert reg.status_code == 200, reg.text
            body = reg.json()
            assert body["access_token"]
            assert body["refresh_token"]
            assert body["expires_in"] == 3600
            assert invite.used_at is not None
            assert verify_password("password1", created_user["u"].password_hash)

            login = await client.post(
                "/v1/auth/login",
                json={"phone": "13800138000", "password": "password1"},
            )
            assert login.status_code == 200
            rt = login.json()["refresh_token"]

            ref = await client.post("/v1/auth/refresh", json={"refresh_token": rt})
            assert ref.status_code == 200, ref.text
            new_rt = ref.json()["refresh_token"]
            assert new_rt != rt
            assert hash_refresh_token(rt) in db._refresh
            assert db._refresh[hash_refresh_token(rt)].revoked_at is not None

            commits_before_reuse = db.commit_count
            reuse = await client.post("/v1/auth/refresh", json={"refresh_token": rt})
            assert reuse.status_code == 401
            # Reuse path must commit so revoke_all_refresh is not rolled back.
            assert db.commit_count == commits_before_reuse + 1
            assert all(
                row.revoked_at is not None
                for row in db._refresh.values()
                if row.user_id == created_user["u"].id
            )
            # Rotated token is also revoked — reuse detection wiped the session.
            reuse_new = await client.post(
                "/v1/auth/refresh", json={"refresh_token": new_rt}
            )
            assert reuse_new.status_code == 401

            bad = await client.post(
                "/v1/auth/login",
                json={"phone": "13800138000", "password": "wrong-pass"},
            )
            assert bad.status_code == 401


@pytest.mark.asyncio
async def test_refresh_reuse_commits_before_401():
    """Handler must commit mass-revoke side effects even when returning 401."""
    settings = Settings(
        env="dev",
        jwt_secret="test-secret",
        jwt_access_expire_minutes=60,
        jwt_refresh_expire_days=7,
    )
    now = datetime.now(timezone.utc)
    user = User(
        id=7,
        apple_sub="phone:13900000000",
        phone="13900000000",
        token_version=0,
        preferred_language="zh",
    )
    old_raw = "old-refresh-token-xx"
    sibling_raw = "sibling-refresh-tok"
    old = RefreshToken(
        id=1,
        user_id=7,
        token_hash=hash_refresh_token(old_raw),
        expires_at=now + timedelta(days=7),
        revoked_at=now,  # already rotated → reuse
    )
    sibling = RefreshToken(
        id=2,
        user_id=7,
        token_hash=hash_refresh_token(sibling_raw),
        expires_at=now + timedelta(days=7),
        revoked_at=None,
    )

    class Sess:
        def __init__(self):
            self._refresh = {old.token_hash: old, sibling.token_hash: sibling}
            self.commit_count = 0

        async def execute(self, stmt):
            result = MagicMock()
            sql = str(stmt).lower()
            compiled = stmt.compile()
            params = dict(compiled.params)
            if "refresh_tokens" in sql and "update" in sql:
                # revoke_all_refresh path
                for row in self._refresh.values():
                    if row.user_id == 7 and row.revoked_at is None:
                        row.revoked_at = datetime.now(timezone.utc)
                result.rowcount = 1
                return result
            th = None
            for v in params.values():
                if isinstance(v, str) and len(v) == 64:
                    th = v
            result.scalar_one_or_none.return_value = self._refresh.get(th)
            return result

        async def commit(self):
            self.commit_count += 1

        async def get(self, model, pk):
            if model is User and pk == 7:
                return user
            return None

        async def flush(self):
            pass

        def add(self, _obj):
            pass

    db = Sess()

    async def override_db():
        yield db

    fake_redis = AsyncMock()
    fake_redis.incr = AsyncMock(return_value=1)
    fake_redis.expire = AsyncMock()

    app = _auth_app()
    from app.core.db import get_db

    app.dependency_overrides[get_db] = override_db

    with patch("app.api.auth.get_settings", return_value=settings), patch(
        "app.services.refresh_tokens.get_settings", return_value=settings
    ), patch(
        "app.services.auth_rate_limit.get_redis", AsyncMock(return_value=fake_redis)
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                "/v1/auth/refresh", json={"refresh_token": old_raw}
            )
            assert res.status_code == 401
            assert db.commit_count == 1
            assert sibling.revoked_at is not None
