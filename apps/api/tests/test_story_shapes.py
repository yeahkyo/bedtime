"""Story shape catalog seed + selection."""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.providers.story_prompt import STORY_SHAPES, select_beat_pattern
from app.services.story_shapes import (
    SHAPE_SEED,
    apply_seed_fallback,
    refresh_shape_catalog,
    seed_story_shapes_if_empty,
    shape_payload,
)


@pytest.fixture(autouse=True)
def _reset_shape_catalog():
    apply_seed_fallback()
    yield
    apply_seed_fallback()


def test_seed_fallback_has_core_shapes():
    ids = {s["id"] for s in SHAPE_SEED}
    assert ids == {"binary_op", "depart_return", "rule_three", "helper", "animism"}
    for s in SHAPE_SEED:
        assert s["guidance"]
        assert s["effect"]
        assert "example_beats" not in s
        assert s["beat_min"] <= s["beat_max"]


def test_shape_payload_has_function_not_slot_hints():
    p = shape_payload("binary_op")
    assert p["story_shape"] == "binary_op"
    assert p["id"] == "binary_op"
    assert p["beat_min"] <= p["beat_max"]
    assert p["beat_hint"] == []
    assert "对立" in p["instruction"]
    assert p["effect"]
    assert shape_payload("not_a_shape")["story_shape"] in STORY_SHAPES


def test_select_avoids_recent_shapes():
    picked = select_beat_pattern(
        episode_no=3,
        salt="x",
        recent_shapes=["binary_op", "depart_return"],
    )
    assert picked["story_shape"] not in ("binary_op", "depart_return")
    assert picked["story_shape"] in STORY_SHAPES


def test_select_stable_for_same_inputs():
    a = select_beat_pattern("tiny_brave", episode_no=1, salt="豆豆")
    b = select_beat_pattern("tiny_brave", episode_no=1, salt="豆豆")
    assert a == b
    assert a["story_shape"] in STORY_SHAPES


@pytest.mark.asyncio
async def test_seed_replaces_legacy_and_upserts():
    from app.models.story_shape import StoryShape

    store: dict[str, object] = {"problem_solve": StoryShape(id="problem_solve")}

    class _Db:
        def add(self, row):
            store[row.id] = row

        async def get(self, _model, pk):
            return store.get(pk)

        async def delete(self, row):
            store.pop(row.id, None)

        async def commit(self):
            return None

        async def execute(self, *_a, **_k):
            result = MagicMock()
            result.scalars.return_value.all.return_value = []
            return result

    with patch(
        "app.services.story_shapes.refresh_shape_catalog", AsyncMock(return_value=5)
    ) as refresh:
        changed = await seed_story_shapes_if_empty(_Db())
    assert "problem_solve" not in store
    assert "binary_op" in store
    assert store["binary_op"].effect
    assert changed >= 6
    refresh.assert_awaited()


@pytest.mark.asyncio
async def test_refresh_empty_uses_fallback():
    class _Db:
        async def execute(self, *_a, **_k):
            result = MagicMock()
            result.scalars.return_value.all.return_value = []
            return result

    n = await refresh_shape_catalog(_Db())
    assert n == 0
    assert shape_payload("binary_op")["story_shape"] == "binary_op"
