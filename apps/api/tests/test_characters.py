"""Character roster: CRUD ownership, child twin, story character_ids."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI, HTTPException
from httpx import ASGITransport, AsyncClient

from app.api import characters as characters_mod
from app.api.characters import router as characters_router
from app.api.children import router as children_router
from app.core.db import get_db
from app.core.security import get_current_user
from app.models.character import Character
from app.models.child import Child
from app.schemas.common import StoryCreate
from app.services.characters import (
    KIND_CHILD,
    KIND_PERSON,
    character_snapshot,
    ensure_child_character,
    load_characters_for_story,
    roster_entry,
)
from app.providers.base import StoryRequest
from app.providers.story_prompt import build_plan_user_message, build_user_payload


def _char(**kwargs) -> Character:
    defaults = dict(
        id=1,
        user_id=7,
        kind=KIND_PERSON,
        name="外公",
        related_child_id=3,
        relation="外公",
        note="爱讲故事",
        listener_child_id=None,
        enabled=True,
    )
    defaults.update(kwargs)
    row = Character(
        user_id=defaults["user_id"],
        kind=defaults["kind"],
        name=defaults["name"],
    )
    for k, v in defaults.items():
        setattr(row, k, v)
    return row


def _child(**kwargs) -> Child:
    defaults = dict(
        id=3,
        user_id=7,
        nickname="小宝",
        age_band="3-5",
        birth_date=None,
        gender="unspecified",
        intro=None,
        interests_json="[]",
    )
    defaults.update(kwargs)
    c = Child(user_id=defaults["user_id"], nickname=defaults["nickname"])
    for k, v in defaults.items():
        setattr(c, k, v)
    return c


@pytest.mark.asyncio
async def test_create_person_rejects_foreign_child():
    app = FastAPI()
    app.include_router(characters_router, prefix="/v1")
    session = MagicMock()
    session.get = AsyncMock(return_value=_child(user_id=99))  # not owner

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=7)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/v1/characters",
            json={
                "kind": "person",
                "name": "外公",
                "related_child_id": 3,
                "relation": "外公",
            },
        )
    assert res.status_code == 404


@pytest.mark.asyncio
async def test_create_rejects_kind_child():
    app = FastAPI()
    app.include_router(characters_router, prefix="/v1")
    session = MagicMock()

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=7)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.post(
            "/v1/characters",
            json={
                "kind": "child",
                "name": "小宝",
                "related_child_id": 3,
            },
        )
    assert res.status_code == 400
    assert "person or toy" in res.json()["detail"]


@pytest.mark.asyncio
async def test_ensure_child_character_idempotent():
    child = _child()
    session = MagicMock()
    session.execute = AsyncMock(
        return_value=MagicMock(
            scalar_one_or_none=MagicMock(return_value=None)
        )
    )
    session.add = MagicMock()
    session.flush = AsyncMock()

    row = await ensure_child_character(session, user_id=7, child=child)
    assert row.kind == KIND_CHILD
    assert row.listener_child_id == child.id
    assert row.related_child_id == child.id
    session.add.assert_called_once()


@pytest.mark.asyncio
async def test_load_characters_missing_raises():
    session = MagicMock()
    session.execute = AsyncMock(
        return_value=MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[]))
            )
        )
    )
    with pytest.raises(HTTPException) as ei:
        await load_characters_for_story(session, user_id=7, character_ids=[9])
    assert ei.value.status_code == 404


@pytest.mark.asyncio
async def test_load_characters_allows_other_child_scope():
    """Selected roster may include characters from any of the user's listeners."""
    row = _char(id=5, related_child_id=99)
    session = MagicMock()
    session.execute = AsyncMock(
        return_value=MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=[row]))
            )
        )
    )
    out = await load_characters_for_story(
        session,
        user_id=7,
        character_ids=[5],
        listener_child_id=3,
    )
    assert [r.id for r in out] == [5]


@pytest.mark.asyncio
async def test_load_characters_order_and_cap():
    rows = [_char(id=i, name=f"n{i}", related_child_id=3) for i in (2, 5, 1)]
    session = MagicMock()
    session.execute = AsyncMock(
        return_value=MagicMock(
            scalars=MagicMock(
                return_value=MagicMock(all=MagicMock(return_value=rows))
            )
        )
    )
    out = await load_characters_for_story(
        session,
        user_id=7,
        character_ids=[5, 2, 5, 1],
        listener_child_id=3,
    )
    assert [r.id for r in out] == [5, 2, 1]


def test_roster_entry_and_prompt_payload():
    row = _char()
    entry = roster_entry(row)
    assert entry == {"name": "外公", "desc": "外公，爱讲故事"}

    req = StoryRequest(
        child_nickname="小宝",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=5,
        roster=[entry],
        audiences=[{"name": "小宝", "age": 4, "gender": "男孩"}],
    )
    payload = build_user_payload(req)
    assert payload["roster"][0]["name"] == "外公"
    assert payload["audiences"][0]["name"] == "小宝"
    plan_msg = build_plan_user_message(req)
    assert "外公" in plan_msg
    assert "roster" in plan_msg
    assert "audiences" in plan_msg


def test_child_snapshot_keeps_age_gender_for_retry():
    from datetime import date

    from app.api.stories import _roster_from_snapshot
    from app.services.child_profile import age_years_int_on

    twin = _char(
        id=11,
        kind=KIND_CHILD,
        name="小宝",
        related_child_id=3,
        listener_child_id=3,
        relation=None,
        note=None,
    )
    birth = date(2021, 6, 1)
    child = _child(id=3, nickname="小宝", birth_date=birth, gender="girl")
    snap = character_snapshot(twin, child=child)
    assert snap["name"] == "小宝"
    assert snap["age"] == age_years_int_on(birth)
    assert snap["gender"] == "女孩"

    rebuilt = _roster_from_snapshot([snap])
    assert rebuilt is not None
    assert rebuilt[0]["name"] == "小宝"
    assert rebuilt[0]["age"] == snap["age"]
    assert rebuilt[0]["gender"] == "女孩"


@pytest.mark.asyncio
async def test_delete_child_character_forbidden():
    app = FastAPI()
    app.include_router(characters_router, prefix="/v1")
    twin = _char(
        id=11,
        kind=KIND_CHILD,
        name="小宝",
        related_child_id=3,
        listener_child_id=3,
        relation=None,
        note=None,
    )
    session = MagicMock()
    session.get = AsyncMock(return_value=twin)

    async def _db():
        yield session

    app.dependency_overrides[get_db] = _db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=7)

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.delete("/v1/characters/11")
    assert res.status_code == 400
