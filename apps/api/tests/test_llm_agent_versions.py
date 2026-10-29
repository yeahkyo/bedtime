"""Prompt version history: increment, restore audit, reset_code snapshot."""

from __future__ import annotations

from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.models.llm_agent import LlmAgent
from app.models.llm_agent_version import LlmAgentVersion
from app.services.llm_agents import (
    CODE_DEFAULTS,
    apply_prompt_fields_and_version,
    get_agent,
    reset_agent_to_code_default,
    restore_agent_version,
    snapshot_agent_version,
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

    def scalar_one(self):
        return self._scalar

    def scalar_one_or_none(self):
        return self._scalar

    def scalars(self):
        return _Scalars(self._rows)


class FakeVersionDb:
    """Minimal async session for llm_agents + llm_agent_versions helpers."""

    def __init__(self, agent: LlmAgent):
        self.agent = agent
        self.versions: list[LlmAgentVersion] = []
        self._auto_id = 1

    async def get(self, model, pk):
        if model is LlmAgent and pk == self.agent.id:
            return self.agent
        return None

    def add(self, obj):
        if isinstance(obj, LlmAgentVersion):
            if obj.id is None:
                obj.id = self._auto_id
                self._auto_id += 1
            self.versions.append(obj)
        elif isinstance(obj, LlmAgent):
            self.agent = obj

    async def flush(self):
        pass

    async def commit(self):
        pass

    async def refresh(self, _obj):
        pass

    async def execute(self, stmt):
        sql = str(stmt).lower()
        agent_id = self.agent.id
        rows = [v for v in self.versions if v.agent_id == agent_id]

        if "count(" in sql:
            return _Result(scalar=len(rows))
        if "max(" in sql or "coalesce" in sql:
            mx = max((v.version for v in rows), default=0)
            return _Result(scalar=mx)

        # select LlmAgentVersion WHERE version == N
        version_eq = None
        for v in rows:
            # match by inspecting bindparams if present
            pass
        try:
            compiled = stmt.compile(compile_kwargs={"literal_binds": True})
            csql = str(compiled)
            for v in rows:
                if f"version = {v.version}" in csql.replace(" ", "").lower().replace(
                    "==", "="
                ) or f"version={v.version}" in csql.replace(" ", ""):
                    version_eq = v
                    break
            # also try "version = N" with spaces
            if version_eq is None:
                import re

                m = re.search(r"version\s*=\s*(\d+)", csql, re.I)
                if m:
                    want = int(m.group(1))
                    version_eq = next((x for x in rows if x.version == want), None)
        except Exception:
            version_eq = None

        if "llm_agent_versions" in sql and version_eq is not None:
            return _Result(scalar=version_eq, rows=[version_eq])

        if "order by" in sql:
            ordered = sorted(rows, key=lambda x: x.version, reverse=True)
            return _Result(rows=ordered)

        if rows and "llm_agent_versions" in sql:
            return _Result(scalar=rows[-1], rows=rows)
        return _Result(scalar=None, rows=[])


def _seed_agent(agent_id: str = "story_draft", system: str = "BASELINE SYS") -> LlmAgent:
    d = CODE_DEFAULTS[agent_id]
    return LlmAgent(
        id=agent_id,
        label_zh=d["label_zh"],
        description=d["description"],
        provider=None,
        model=None,
        system_prompt=system,
        user_prompt_template=d.get("user_prompt_template") or "{{user_payload}}",
        max_tokens=d.get("max_tokens"),
        timeout_seconds=d.get("timeout_seconds"),
        temperature=0.5,
        placeholders_json=d["placeholders_json"],
        enabled=True,
    )


@pytest.mark.asyncio
async def test_save_twice_increments_versions_and_updates_current():
    agent = _seed_agent(system="V0")
    db = FakeVersionDb(agent)

    await apply_prompt_fields_and_version(
        db,
        agent,
        system_prompt="V1-NEW",
        source="admin_save",
        created_by="ops",
        note="first edit",
    )
    # baseline v1 = V0, then v2 = V1-NEW
    assert [v.version for v in db.versions] == [1, 2]
    assert db.versions[0].system_prompt == "V0"
    assert db.versions[0].note == "保存前基线"
    assert db.versions[1].system_prompt == "V1-NEW"
    assert db.versions[1].source == "admin_save"
    assert agent.system_prompt == "V1-NEW"

    await apply_prompt_fields_and_version(
        db,
        agent,
        system_prompt="V2-NEW",
        source="admin_save",
        created_by="ops",
        note="second",
    )
    assert [v.version for v in db.versions] == [1, 2, 3]
    assert db.versions[-1].system_prompt == "V2-NEW"
    assert db.versions[-1].note == "second"
    assert agent.system_prompt == "V2-NEW"


@pytest.mark.asyncio
async def test_restore_writes_current_and_adds_restore_version():
    agent = _seed_agent(system="NOW")
    db = FakeVersionDb(agent)
    # seed two history rows manually
    db.versions.append(
        LlmAgentVersion(
            id=1,
            agent_id=agent.id,
            version=1,
            note="old",
            system_prompt="OLD SYS",
            user_prompt_template="{{user_payload}}",
            temperature=0.2,
            max_tokens=100,
            timeout_seconds=30,
            source="admin_save",
            created_by="ops",
        )
    )
    db.versions.append(
        LlmAgentVersion(
            id=2,
            agent_id=agent.id,
            version=2,
            note="cur",
            system_prompt="NOW",
            user_prompt_template="{{user_payload}}",
            temperature=0.5,
            max_tokens=100,
            timeout_seconds=30,
            source="admin_save",
            created_by="ops",
        )
    )
    db._auto_id = 3

    row = await restore_agent_version(db, agent.id, 1, created_by="ops", note="")
    assert row.system_prompt == "OLD SYS"
    assert row.temperature == 0.2
    assert db.versions[-1].source == "restore"
    assert db.versions[-1].version == 3
    assert db.versions[-1].system_prompt == "OLD SYS"
    assert "v1" in (db.versions[-1].note or "").lower() or "回滚" in (
        db.versions[-1].note or ""
    )


@pytest.mark.asyncio
async def test_reset_snapshots_reset_code():
    agent = _seed_agent(system="CUSTOM")
    db = FakeVersionDb(agent)

    # Avoid create_all path; patch get so reset finds our agent via FakeVersionDb
    with patch.object(db, "get", side_effect=db.get):
        row = await reset_agent_to_code_default(db, agent.id, created_by="ops")

    assert row.system_prompt == CODE_DEFAULTS[agent.id]["system_prompt"]
    assert any(v.source == "reset_code" for v in db.versions)
    # baseline + reset
    assert len(db.versions) >= 2
    assert db.versions[0].system_prompt == "CUSTOM"
    assert db.versions[-1].source == "reset_code"


@pytest.mark.asyncio
async def test_get_agent_still_reads_only_current_row():
    """Runtime get_agent ignores version table — only llm_agents current row."""
    row = SimpleNamespace(
        id="story_draft",
        label_zh="x",
        description="",
        provider=None,
        model=None,
        system_prompt="LIVE ONLY",
        user_prompt_template="{{user_payload}}",
        max_tokens=100,
        timeout_seconds=10,
        temperature=0.3,
        placeholders_json="[]",
        enabled=True,
    )

    class _Db:
        async def get(self, _model, _pk):
            return row

    cfg = await get_agent(_Db(), "story_draft")
    assert cfg.system_prompt == "LIVE ONLY"
    assert cfg.from_db is True


@pytest.mark.asyncio
async def test_admin_versions_list_get_restore_lab_save_api():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    agent = _seed_agent(system="CURRENT")
    versions = [
        LlmAgentVersion(
            id=1,
            agent_id="story_draft",
            version=1,
            note="n1",
            system_prompt="OLD",
            user_prompt_template="{{user_payload}}",
            temperature=0.1,
            max_tokens=50,
            timeout_seconds=20,
            source="admin_save",
            created_by="ops",
            created_at=None,
        )
    ]

    class _Db:
        async def get(self, model, pk):
            if model is LlmAgent and pk == "story_draft":
                return agent
            return None

        async def commit(self):
            pass

        async def refresh(self, _row):
            pass

        async def flush(self):
            pass

        def add(self, obj):
            if isinstance(obj, LlmAgentVersion):
                versions.append(obj)

        async def execute(self, stmt):
            sql = str(stmt).lower()
            if "order by" in sql:
                return _Result(rows=list(reversed(versions)))
            try:
                import re

                csql = str(stmt.compile(compile_kwargs={"literal_binds": True}))
                m = re.search(r"version\s*=\s*(\d+)", csql, re.I)
                if m:
                    want = int(m.group(1))
                    hit = next((v for v in versions if v.version == want), None)
                    return _Result(scalar=hit, rows=[hit] if hit else [])
            except Exception:
                pass
            return _Result(scalar=versions[0] if versions else None, rows=versions)

    async def _db_dep():
        yield _Db()

    app.dependency_overrides[require_admin] = lambda: "ops"
    app.dependency_overrides[get_db] = _db_dep

    restored = _seed_agent(system="OLD")
    restored.temperature = 0.1

    with (
        patch(
            "app.api.admin.llm_agents.seed_llm_agents_if_missing",
            AsyncMock(return_value=0),
        ),
        patch(
            "app.api.admin.llm_agents.restore_agent_version",
            AsyncMock(return_value=restored),
        ) as restore_mock,
        patch(
            "app.api.admin.llm_agents.apply_prompt_fields_and_version",
            AsyncMock(return_value=MagicMock()),
        ) as apply_mock,
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            listed = await client.get("/admin/llm-agents/story_draft/versions")
            assert listed.status_code == 200
            assert listed.json()["total"] == 1
            assert listed.json()["items"][0]["version"] == 1

            detail = await client.get("/admin/llm-agents/story_draft/versions/1")
            assert detail.status_code == 200
            assert detail.json()["system_prompt"] == "OLD"

            res = await client.post(
                "/admin/llm-agents/story_draft/versions/1/restore",
                json={"note": "back"},
            )
            assert res.status_code == 200
            assert res.json()["system_prompt"] == "OLD"
            restore_mock.assert_awaited_once()

            lab = await client.post(
                "/admin/llm-agents/story_draft/lab-save",
                json={
                    "system_prompt": "FROM LAB",
                    "user_prompt_template": "{{user_payload}}",
                    "temperature": 0.55,
                    "version_note": "lab note",
                },
            )
            assert lab.status_code == 200
            apply_mock.assert_awaited()
            kwargs = apply_mock.await_args.kwargs
            assert kwargs["source"] == "lab_save"
            assert kwargs["system_prompt"] == "FROM LAB"
            assert kwargs["note"] == "lab note"


@pytest.mark.asyncio
async def test_llm_lab_defaults_returns_disabled_db_row():
    """Lab defaults must not substitute code fallback when agent is disabled."""
    from app.api.admin.llm_lab import router as lab_router

    app = FastAPI()
    app.include_router(lab_router, prefix="/admin")

    agent = _seed_agent(system="DISABLED CUSTOM")
    agent.enabled = False

    class _Db:
        async def get(self, model, pk):
            if model is LlmAgent and pk == "story_draft":
                return agent
            return None

    async def _db_dep():
        yield _Db()

    app.dependency_overrides[require_admin] = lambda: "ops"
    app.dependency_overrides[get_db] = _db_dep

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        res = await client.get(
            "/admin/llm-lab/defaults",
            params={"agent_id": "story_draft"},
        )
    assert res.status_code == 200
    body = res.json()
    assert body["system_prompt"] == "DISABLED CUSTOM"
    assert body["from_db"] is True
    assert body["enabled"] is False


@pytest.mark.asyncio
async def test_snapshot_agent_version_source_fields():
    agent = _seed_agent()
    db = FakeVersionDb(agent)
    # pretend history already exists so next is 1 from empty... empty → next=1
    snap = await snapshot_agent_version(
        db, agent, source="lab_save", created_by="ops", note="x"
    )
    assert snap.version == 1
    assert snap.source == "lab_save"
    assert snap.created_by == "ops"
    assert snap.note == "x"
    assert snap.temperature == agent.temperature
