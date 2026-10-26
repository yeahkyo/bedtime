"""LLM agent templates, seed/reset, admin API, pipeline fallback."""

import json
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.api.admin import router as admin_router
from app.core.db import get_db
from app.core.security import require_admin
from app.services.llm_agents import (
    AGENT_IDS,
    CODE_DEFAULTS,
    DEFAULT_TEMPERATURE,
    build_chat_messages,
    code_default_config,
    get_agent,
    render_template,
    reset_agent_to_code_default,
    resolve_temperature,
    seed_llm_agents_if_missing,
)
from app.services.llm_routing import LlmChoice


def _fake_llm_choice(ctx) -> LlmChoice:
    return LlmChoice(
        provider=ctx.default_provider or "mock",
        model=ctx.agent_model or "test-model",
        tier=None,
        reasons=("test",),
    )


def test_resolve_temperature_default_and_clamp():
    assert resolve_temperature(None) == DEFAULT_TEMPERATURE
    assert resolve_temperature(0.3) == 0.3
    assert resolve_temperature(-1) == 0.0
    assert resolve_temperature(9) == 2.0


def test_render_template_replaces_and_warns_missing(caplog):
    out = render_template("Hi {{name}} / {{missing}}", {"name": "Ada"})
    assert out == "Hi Ada / "
    assert "placeholder missing: missing" in caplog.text


def test_render_template_json_values():
    out = render_template("{{user_payload}}", {"user_payload": {"a": 1}})
    assert out == '{"a": 1}'


def test_build_chat_messages_default_user_payload():
    cfg = code_default_config("story_draft")
    system, user = build_chat_messages(
        cfg,
        user_payload='{"theme":"moon"}',
        extra_vars={"theme": "moon", "age_band": "3-5"},
    )
    assert '{"theme":"moon"}' in user
    assert "请根据以下大纲写睡前故事正文" in user
    assert system  # non-empty system from code default


def test_code_defaults_cover_first_wave_agents():
    assert set(AGENT_IDS) == set(CODE_DEFAULTS)
    for aid in AGENT_IDS:
        d = CODE_DEFAULTS[aid]
        assert d["system_prompt"].strip()
        assert "{{user_payload}}" in (d["user_prompt_template"] or "")
        names = {p["name"] for p in json.loads(d["placeholders_json"])}
        assert "user_payload" in names
        # No redundant scalars that already live inside user_payload JSON.
        assert names.isdisjoint(
            {
                "theme",
                "age_band",
                "child_nickname",
                "language",
                "duration_minutes",
                "age_stage",
                "axis_or_subcategory",
                "count",
                "theory_hint",
            }
        )
    # Story agents: task lead in user template (not bare payload).
    assert "{{episode_count}}" in CODE_DEFAULTS["story_series_outline"]["user_prompt_template"]
    outline_names = {
        p["name"]
        for p in json.loads(CODE_DEFAULTS["story_series_outline"]["placeholders_json"])
    }
    assert outline_names == {"user_payload", "episode_count"}
    assert {
        p["name"]
        for p in json.loads(CODE_DEFAULTS["story_episode_plan"]["placeholders_json"])
    } == {"user_payload"}
    assert {
        p["name"]
        for p in json.loads(CODE_DEFAULTS["story_draft"]["placeholders_json"])
    } == {"user_payload"}
    assert "构思今晚" in CODE_DEFAULTS["story_episode_plan"]["user_prompt_template"]
    assert "写睡前故事正文" in CODE_DEFAULTS["story_draft"]["user_prompt_template"]


@pytest.mark.asyncio
async def test_get_agent_falls_back_when_disabled_or_empty():
    disabled = SimpleNamespace(
        id="story_draft",
        label_zh="x",
        description="",
        provider=None,
        model=None,
        system_prompt="CUSTOM",
        user_prompt_template="{{user_payload}}",
        max_tokens=100,
        timeout_seconds=10,
        temperature=0.9,
        placeholders_json="[]",
        enabled=False,
    )
    empty = SimpleNamespace(
        id="story_draft",
        label_zh="x",
        description="",
        provider=None,
        model=None,
        system_prompt="   ",
        user_prompt_template="{{user_payload}}",
        max_tokens=None,
        timeout_seconds=None,
        temperature=None,
        placeholders_json="[]",
        enabled=True,
    )

    class _Db:
        def __init__(self, row):
            self._row = row

        async def get(self, _model, _id):
            return self._row

    fb = await get_agent(_Db(disabled), "story_draft")
    assert fb.from_db is False
    assert "CUSTOM" not in fb.system_prompt

    fb2 = await get_agent(_Db(empty), "story_draft")
    assert fb2.from_db is False


@pytest.mark.asyncio
async def test_seed_does_not_overwrite_existing():
    existing = SimpleNamespace(id="story_draft")
    added: list = []

    class _Db:
        async def get(self, _model, agent_id):
            if agent_id == "story_draft":
                return existing
            return None

        def add(self, row):
            added.append(row.id)

        async def commit(self):
            pass

    inserted = await seed_llm_agents_if_missing(_Db())
    assert "story_draft" not in added
    assert inserted == len(AGENT_IDS) - 1


@pytest.mark.asyncio
async def test_seed_never_mutates_existing_prompts():
    """Restart seed must not rewrite Admin-saved system/user/placeholders."""
    custom_system = "CUSTOM PLAN SYSTEM — keep me"
    custom_user = "{{user_payload}}"
    custom_ph = "[]"
    row = SimpleNamespace(
        id="story_episode_plan",
        system_prompt=custom_system,
        user_prompt_template=custom_user,
        description="old",
        placeholders_json=custom_ph,
    )
    committed = {"n": 0}

    class _Db:
        async def get(self, _model, agent_id):
            if agent_id == "story_episode_plan":
                return row
            return SimpleNamespace(
                id=agent_id,
                system_prompt=CODE_DEFAULTS[agent_id]["system_prompt"],
                user_prompt_template=CODE_DEFAULTS[agent_id]["user_prompt_template"],
                description="ok",
                placeholders_json=CODE_DEFAULTS[agent_id]["placeholders_json"],
            )

        def add(self, _row):
            raise AssertionError("should not insert")

        async def commit(self):
            committed["n"] += 1

    inserted = await seed_llm_agents_if_missing(_Db())
    assert inserted == 0
    assert committed["n"] == 0
    assert row.system_prompt == custom_system
    assert row.user_prompt_template == custom_user
    assert row.placeholders_json == custom_ph


@pytest.mark.asyncio
async def test_reset_restores_code_default():
    row = MagicMock()
    row.id = "catalog_element_gen"
    row.system_prompt = "OPS EDIT"
    row.user_prompt_template = "custom {{user_payload}}"
    row.provider = "openai"
    row.model = "gpt-x"
    row.max_tokens = 1
    row.timeout_seconds = 1
    row.temperature = 1.2
    row.enabled = False
    row.label_zh = "旧"
    row.description = "旧"
    row.placeholders_json = "[]"

    class _Db:
        async def get(self, _model, _id):
            return row

        def add(self, _row):
            raise AssertionError("should update existing")

        async def commit(self):
            pass

        async def refresh(self, _row):
            pass

    out = await reset_agent_to_code_default(_Db(), "catalog_element_gen")
    assert out.system_prompt == CODE_DEFAULTS["catalog_element_gen"]["system_prompt"]
    assert out.enabled is True
    assert out.provider is None


@pytest.mark.asyncio
async def test_admin_list_patch_reset_smoke():
    app = FastAPI()
    app.include_router(admin_router, prefix="/admin")

    store: dict[str, MagicMock] = {}

    def _make_row(agent_id: str) -> MagicMock:
        d = CODE_DEFAULTS[agent_id]
        row = MagicMock()
        row.id = agent_id
        row.label_zh = d["label_zh"]
        row.description = d["description"]
        row.provider = d.get("provider")
        row.model = d.get("model")
        row.system_prompt = d["system_prompt"]
        row.user_prompt_template = d.get("user_prompt_template") or "{{user_payload}}"
        row.max_tokens = d.get("max_tokens")
        row.timeout_seconds = d.get("timeout_seconds")
        row.temperature = d.get("temperature")
        row.placeholders_json = d["placeholders_json"]
        row.enabled = True
        row.updated_at = None
        return row

    for aid in AGENT_IDS:
        store[aid] = _make_row(aid)

    class _Db:
        async def get(self, _model, agent_id):
            return store.get(agent_id)

        def add(self, row):
            store[row.id] = row

        async def commit(self):
            pass

        async def refresh(self, row):
            pass

    async def _db():
        yield _Db()

    app.dependency_overrides[require_admin] = lambda: "ops"
    app.dependency_overrides[get_db] = _db

    with patch(
        "app.api.admin.llm_agents.seed_llm_agents_if_missing",
        AsyncMock(return_value=0),
    ):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            listed = await client.get("/admin/llm-agents")
            assert listed.status_code == 200
            body = listed.json()
            assert body["total"] == len(AGENT_IDS)
            assert "Agent model" in body["priority_hint"]

            patched = await client.patch(
                "/admin/llm-agents/story_draft",
                json={
                    "system_prompt": "EDITED SYSTEM",
                    "enabled": True,
                    "temperature": 0.4,
                },
            )
            assert patched.status_code == 200
            assert patched.json()["system_prompt"] == "EDITED SYSTEM"
            assert patched.json()["temperature"] == 0.4
            assert store["story_draft"].system_prompt == "EDITED SYSTEM"
            assert store["story_draft"].temperature == 0.4

            cleared = await client.patch(
                "/admin/llm-agents/story_draft",
                json={"clear_temperature": True},
            )
            assert cleared.status_code == 200
            assert cleared.json()["temperature"] is None

            with patch(
                "app.api.admin.llm_agents.reset_agent_to_code_default",
                AsyncMock(return_value=_make_row("story_draft")),
            ) as reset_mock:
                reset = await client.post("/admin/llm-agents/story_draft/reset")
                assert reset.status_code == 200
                reset_mock.assert_awaited_once()


@pytest.mark.asyncio
async def test_pipeline_uses_agent_messages_with_fallback():
    """Without DB agent, pipeline still chats with code-default system text."""
    from app.providers.base import StoryRequest
    from app.providers.story_pipeline import run_story_pipeline
    from app.providers.story_prompt import SYSTEM_PROMPT

    calls: list[dict] = []

    async def chat(
        system,
        user,
        *,
        max_tokens,
        timeout,
        stage="chat",
        model=None,
        **_kwargs,
    ):
        calls.append({"stage": stage, "system": system, "model": model})
        if stage == "episode_plan":
            assert "构思今晚睡前故事大纲" in user
            start = user.find("{")
            payload = json.loads(user[start:])
            assert set(payload) == {
                "theme",
                "audiences",
                "roster",
                "fantasy",
                "len",
            }
            assert payload["len"] == "660-1100"  # short tier LLM ref 4 min ±1 @ 220 chars/min
            return (
                '{"title":"月亮夜","theme":"窗边一点光","core":"一点暖光",'
                '"casts":[{"name":"豆豆","desc":"爱踮脚看月亮的孩子"}],'
                '"beats":["踮脚","看月亮","靠着窗坐下"],'
                '"shape":"一点点靠近再安静"}'
            )
        assert "写睡前故事正文" in user
        start = user.find("{")
        draft_payload = json.loads(user[start:])
        assert "roster" not in draft_payload
        assert "casts" in draft_payload
        return '{"title":"夜","body":"从前有个孩子。晚安。"}'

    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=3,
        soft_series_mode=False,
    )

    with (
        patch(
            "app.providers.story_pipeline.get_agent_standalone",
            side_effect=lambda aid: code_default_config(aid),
        ),
        patch(
            "app.providers.story_pipeline.resolve_llm_choice_standalone",
            AsyncMock(side_effect=_fake_llm_choice),
        ),
    ):
        result = await run_story_pipeline(req, chat=chat)

    assert result.title
    assert any(c["stage"] == "draft" for c in calls)
    draft = next(c for c in calls if c["stage"] == "draft")
    assert draft["system"] == SYSTEM_PROMPT
    assert result.prompts
    saved = {row["stage"]: row for row in result.prompts}
    assert set(saved) == {"episode_plan", "draft"}
    assert saved["draft"]["system"] == draft["system"]
    assert saved["draft"]["user"]
    assert saved["episode_plan"]["system"]
    assert '"fantasy"' in saved["episode_plan"]["user"]
    assert '"casts"' in saved["draft"]["user"]


@pytest.mark.asyncio
async def test_pipeline_skips_plan_llm_when_episode_plan_provided():
    from app.providers.base import StoryRequest
    from app.providers.story_pipeline import run_story_pipeline

    calls: list[str] = []

    async def chat(system, user, *, stage="chat", **_kwargs):
        calls.append(stage)
        if stage == "episode_plan":
            raise AssertionError("plan LLM should be skipped")
        return '{"title":"夜","body":"从前有个孩子。晚安。"}'

    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=3,
        soft_series_mode=False,
        episode_plan={
            "title": "月亮夜",
            "theme": "窗边一点光",
            "casts": [{"name": "豆豆", "desc": "爱踮脚看月亮的孩子"}],
            "beats": ["踮脚", "看月亮", "靠着窗坐下"],
            "shape": "一点点靠近再安静",
        },
    )
    with (
        patch(
            "app.providers.story_pipeline.get_agent_standalone",
            side_effect=lambda aid: code_default_config(aid),
        ),
        patch(
            "app.providers.story_pipeline.resolve_llm_choice_standalone",
            AsyncMock(side_effect=_fake_llm_choice),
        ),
    ):
        result = await run_story_pipeline(req, chat=chat)

    assert calls == ["draft"]
    assert result.title
    assert result.episode_plan["title"] == "月亮夜"
    stages = (result.metrics or {}).get("stages") or []
    assert stages[0]["stage"] == "episode_plan"
    assert stages[0].get("skipped") is True
    assert stages[1]["stage"] == "draft"
    assert [p["stage"] for p in (result.prompts or [])] == ["draft"]


@pytest.mark.asyncio
async def test_pipeline_calls_on_plan_before_draft():
    from app.providers.base import StoryRequest
    from app.providers.story_pipeline import run_story_pipeline

    seen: list[dict] = []

    async def chat(system, user, *, stage="chat", **_kwargs):
        if stage == "draft":
            return '{"title":"夜","body":"从前有个孩子。晚安。"}'
        return (
            '{"title":"月亮夜","theme":"窗边一点光","casts":'
            '[{"name":"豆豆","desc":"爱踮脚看月亮的孩子"}],'
            '"beats":["踮脚","看月亮","靠着窗坐下"],'
            '"shape":"一点点靠近再安静"}'
        )

    async def on_plan(plan):
        seen.append(plan)

    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=3,
        soft_series_mode=False,
    )
    with (
        patch(
            "app.providers.story_pipeline.get_agent_standalone",
            side_effect=lambda aid: code_default_config(aid),
        ),
        patch(
            "app.providers.story_pipeline.resolve_llm_choice_standalone",
            AsyncMock(side_effect=_fake_llm_choice),
        ),
    ):
        await run_story_pipeline(req, chat=chat, on_plan=on_plan)

    assert len(seen) == 1
    assert seen[0]["title"] == "月亮夜"


@pytest.mark.asyncio
async def test_pipeline_keeps_submitted_prompts_when_draft_fails():
    from app.providers.base import StoryRequest
    from app.providers.story_pipeline import dumps_submitted_prompts, run_story_pipeline

    async def chat(system, user, *, stage="chat", **_kwargs):
        if stage == "draft":
            raise RuntimeError("draft down")
        return (
            '{"title":"月亮夜","theme":"窗边一点光","casts":'
            '[{"name":"豆豆","desc":"爱踮脚看月亮的孩子"}],'
            '"beats":["踮脚","看月亮","靠着窗坐下"],'
            '"shape":"一点点靠近再安静"}'
        )

    req = StoryRequest(
        child_nickname="豆豆",
        age_band="3-5",
        language="zh",
        theme="月亮",
        duration_minutes=3,
        soft_series_mode=False,
    )

    with (
        patch(
            "app.providers.story_pipeline.get_agent_standalone",
            side_effect=lambda aid: code_default_config(aid),
        ),
        patch(
            "app.providers.story_pipeline.resolve_llm_choice_standalone",
            AsyncMock(side_effect=_fake_llm_choice),
        ),
    ):
        with pytest.raises(RuntimeError) as raised:
            await run_story_pipeline(req, chat=chat)

    prompts = getattr(raised.value, "submitted_prompts", None)
    assert prompts
    assert [row["stage"] for row in prompts] == ["episode_plan", "draft"]
    plan = getattr(raised.value, "submitted_episode_plan", None)
    assert isinstance(plan, dict)
    assert plan.get("title") == "月亮夜"
    assert plan.get("casts")
    metrics = getattr(raised.value, "submitted_metrics", None)
    assert isinstance(metrics, dict)
    assert [row["stage"] for row in metrics.get("stages") or []] == ["episode_plan"]
    raw = dumps_submitted_prompts(prompts)
    assert raw
    loaded = json.loads(raw)
    assert loaded["stages"][1]["stage"] == "draft"
    assert loaded["stages"][1]["system"]
    assert loaded["stages"][1]["user"]


def test_merge_submitted_prompts_keeps_plan_across_draft_retry():
    from app.providers.story_pipeline import merge_submitted_prompts

    prior = json.dumps(
        {
            "stages": [
                {"stage": "episode_plan", "system": "plan-sys", "user": "plan-user"},
                {"stage": "draft", "system": "old-draft", "user": "old"},
            ]
        },
        ensure_ascii=False,
    )
    merged = merge_submitted_prompts(
        prior,
        [{"stage": "draft", "system": "new-draft", "user": "new"}],
    )
    assert merged
    stages = json.loads(merged)["stages"]
    assert [s["stage"] for s in stages] == ["episode_plan", "draft"]
    assert stages[0]["system"] == "plan-sys"
    assert stages[1]["system"] == "new-draft"
