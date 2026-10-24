from datetime import date
from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.children import router as children_router
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.services.child_profile import (
    age_band_from_birth_date,
    age_months_on,
    age_years_int_on,
    approximate_birth_date_from_age_band,
    normalize_gender,
    sync_age_band,
)


def test_normalize_gender():
    assert normalize_gender("girl") == "girl"
    assert normalize_gender("男") == "boy"
    assert normalize_gender("female") == "girl"
    assert normalize_gender(None) == "unspecified"
    assert normalize_gender("???") == "unspecified"


def test_age_band_from_birth_date():
    today = date(2026, 10, 15)
    assert age_band_from_birth_date(date(2024, 10, 15), on=today) == "2-3"
    assert age_band_from_birth_date(date(2022, 1, 1), on=today) == "3-5"
    assert age_band_from_birth_date(date(2018, 1, 1), on=today) == "6-8"
    assert age_band_from_birth_date(date(2016, 1, 1), on=today) == "9-12"
    assert age_band_from_birth_date(None) == "3-5"


def test_age_months_from_birth_date():
    today = date(2026, 10, 15)
    assert age_months_on(date(2024, 10, 15), on=today) == 24
    assert age_months_on(date(2020, 5, 1), on=today) == 77
    assert age_months_on(None) == 48


def test_age_years_int_from_birth_date():
    today = date(2026, 10, 15)
    assert age_years_int_on(date(2024, 10, 15), on=today) == 2
    assert age_years_int_on(date(2020, 5, 1), on=today) == 6
    assert age_years_int_on(None) == 4


def test_sync_and_legacy_approx():
    birth = approximate_birth_date_from_age_band("3-5", on=date(2026, 10, 15))
    assert sync_age_band(birth) == "3-5"
    assert sync_age_band(None, "6-8") == "6-8"


@pytest.mark.asyncio
async def test_patch_age_band_preserves_existing_birth_date():
    app = FastAPI()
    app.include_router(children_router)

    precise = date(2020, 5, 1)
    child = SimpleNamespace(
        id=1,
        user_id=7,
        nickname="豆豆",
        birth_date=precise,
        age_band="3-5",
        gender="girl",
        intro=None,
        interests_json="[]",
    )

    class _Db:
        async def get(self, _model, child_id):
            return child if child_id == 1 else None

        async def execute(self, _stmt):
            return MagicMock(scalar_one_or_none=MagicMock(return_value=None))

        def add(self, _obj):
            return None

        async def flush(self):
            return None

        async def commit(self):
            return None

        async def refresh(self, _obj):
            return None

    async def _db():
        yield _Db()

    async def _user():
        return User(id=7, apple_sub="t")

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = _user

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.patch("/children/1", json={"age_band": "6-8"})
    assert res.status_code == 200
    assert child.birth_date == precise
    assert child.age_band == sync_age_band(precise)
