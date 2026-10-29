"""Theme spark hint suppression after theme_source=hint creates."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.theme_sparks import (
    list_enabled_sparks_for_user,
    record_theme_spark_hint_use,
)


class _Scalars:
    def __init__(self, rows):
        self._rows = rows

    def all(self):
        return list(self._rows)


class _Result:
    def __init__(self, *, scalar=None, rows=None):
        self._scalar = scalar
        self._rows = rows or []

    def scalar_one_or_none(self):
        return self._scalar

    def scalars(self):
        return _Scalars(self._rows)


@pytest.mark.asyncio
async def test_list_for_user_excludes_used_until_exhausted(monkeypatch):
    sparks = [
        SimpleNamespace(id=1, text="a", enabled=True),
        SimpleNamespace(id=2, text="b", enabled=True),
    ]

    class _Db:
        used_ids = [1]

        async def execute(self, _stmt):
            return _Result(rows=list(self.used_ids))

        async def get(self, *_a, **_k):
            return None

    monkeypatch.setattr(
        "app.services.theme_sparks.list_enabled_sparks",
        AsyncMock(return_value=sparks),
    )
    out = await list_enabled_sparks_for_user(_Db(), language="zh", user_id=9)
    assert [s.id for s in out] == [2]

    # All used → return full list again.
    db2 = _Db()
    db2.used_ids = [1, 2]
    out2 = await list_enabled_sparks_for_user(db2, language="zh", user_id=9)
    assert [s.id for s in out2] == [1, 2]


@pytest.mark.asyncio
async def test_record_theme_spark_hint_use_skips_dup_and_missing():
    added = []

    class _Db:
        async def get(self, _model, pk):
            if pk == 5:
                return SimpleNamespace(id=5, enabled=True)
            return None

        async def execute(self, _stmt):
            return _Result(scalar=None)

        def add(self, obj):
            added.append(obj)

    db = _Db()
    await record_theme_spark_hint_use(db, user_id=1, spark_id=None)
    await record_theme_spark_hint_use(db, user_id=1, spark_id=99)
    assert added == []
    await record_theme_spark_hint_use(db, user_id=1, spark_id=5)
    assert len(added) == 1
    assert added[0].spark_id == 5


@pytest.mark.asyncio
async def test_record_resolves_spark_by_theme_text():
    added = []

    class _Db:
        async def get(self, *_a, **_k):
            return None

        async def execute(self, _stmt):
            # First call in resolve: text match → id 7; second: exists check → None
            if not hasattr(self, "_n"):
                self._n = 0
            self._n += 1
            if self._n == 1:
                return _Result(scalar=7)
            return _Result(scalar=None)

        def add(self, obj):
            added.append(obj)

    await record_theme_spark_hint_use(
        _Db(), user_id=1, spark_id=None, theme="我不想睡觉", language="zh"
    )
    assert len(added) == 1
    assert added[0].spark_id == 7
