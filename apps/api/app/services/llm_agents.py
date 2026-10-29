"""LLM agent configs: DB-backed prompts with {{placeholder}} rendering + code fallback."""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import SessionLocal
from app.models.llm_agent import LlmAgent
from app.models.llm_agent_version import LlmAgentVersion
from app.providers.story_prompt import (
    PLAN_SYSTEM_PROMPT,
    SERIES_OUTLINE_SYSTEM_PROMPT,
    SYSTEM_PROMPT as DRAFT_SYSTEM_PROMPT,
)
from app.services.element_generation import SYSTEM_PROMPT as ELEMENT_SYSTEM_PROMPT
from app.services.kernel_generation import SYSTEM_PROMPT as KERNEL_SYSTEM_PROMPT

logger = logging.getLogger(__name__)

_PLACEHOLDER_RE = re.compile(r"\{\{\s*([a-zA-Z0-9_]+)\s*\}\}")

DEFAULT_USER_TEMPLATE = "{{user_payload}}"
DEFAULT_TEMPERATURE = 0.7

# Task leads live in Agent user templates (editable in Admin); code only supplies JSON.
OUTLINE_USER_TEMPLATE = (
    "请为软系列设计 {{episode_count}} 集睡前大纲。只输出 JSON（短字段名）。"
    "theme_mode=seed 时 arc/premise 跟 theme 灵感自由展开；"
    "theme_mode=plot 时 arc/premise 跟用户 theme 情节骨架，可润色勿改主线。"
    "禁止整季围着某个兴趣偏好转。\n"
    "{{user_payload}}"
)
PLAN_USER_TEMPLATE = (
    "请根据以下输入构思今晚睡前故事大纲。"
    "遵守 theme_mode（seed=灵感种子自由构思；plot=按用户情节骨架，勿改主线）。"
    "只输出 JSON（字段：title、theme、casts、beats、shape），不要正文、不要 markdown。\n"
    "{{user_payload}}"
)
DRAFT_USER_TEMPLATE = (
    "请根据以下大纲写睡前故事正文。"
    "只输出 JSON 对象（字段 title、body；不要 markdown）。\n"
    "{{user_payload}}"
)

AGENT_IDS = (
    "story_series_outline",
    "story_episode_plan",
    "story_draft",
    "catalog_element_gen",
    "catalog_kernel_gen",
)


def _ph(*items: tuple[str, str]) -> str:
    return json.dumps(
        [{"name": n, "description": d} for n, d in items],
        ensure_ascii=False,
    )


CODE_DEFAULTS: dict[str, dict[str, Any]] = {
    "story_series_outline": {
        "label_zh": "软系列大纲",
        "description": "为软系列设计多集温和大纲（不写正文）。任务说明在 User 模板；JSON 由代码组装。",
        "provider": None,
        "model": None,
        "system_prompt": SERIES_OUTLINE_SYSTEM_PROMPT,
        "user_prompt_template": OUTLINE_USER_TEMPLATE,
        "max_tokens": 4096,
        "timeout_seconds": 180,
        "temperature": None,
        # Only list placeholders used by the default User template (docs for Admin).
        "placeholders_json": _ph(
            (
                "user_payload",
                "代码组装的纯 JSON：n/theme/theme_mode/lang/age/gender/age_how/roster/"
                "cast_tip/dials/focus_pool/focus_seed",
            ),
            ("episode_count", "系列集数（已钳制 2–8），供 User 模板 lead 使用"),
        ),
        "enabled": True,
    },
    "story_episode_plan": {
        "label_zh": "单集构思",
        "description": "根据今晚输入产出大纲 JSON（不写正文）。任务说明在 User 模板。",
        "provider": None,
        "model": None,
        "system_prompt": PLAN_SYSTEM_PROMPT,
        "user_prompt_template": PLAN_USER_TEMPLATE,
        "max_tokens": 2048,
        "timeout_seconds": 120,
        "temperature": None,
        "placeholders_json": _ph(
            (
                "user_payload",
                "代码组装的纯 JSON：theme/theme_mode/roster/fantasy/len"
                "（theme_mode=seed|plot；len 为「下限-上限」；三档参考 4/7/10 分±1×220字/分）",
            ),
        ),
        "enabled": True,
    },
    "story_draft": {
        "label_zh": "正文润色",
        "description": "按大纲 JSON 写成可听口语正文。任务说明在 User 模板。",
        "provider": None,
        "model": None,
        "system_prompt": DRAFT_SYSTEM_PROMPT,
        "user_prompt_template": DRAFT_USER_TEMPLATE,
        "max_tokens": None,  # duration-based in code
        "timeout_seconds": None,  # duration-based in code
        "temperature": None,
        "placeholders_json": _ph(
            (
                "user_payload",
                "代码组装的纯 JSON：title/theme/casts/beats/age/gender/dialog/len/roster"
                "（len 为「下限-上限」；三档参考 4/7/10 分±1×220字/分）",
            ),
        ),
        "enabled": True,
    },
    "catalog_element_gen": {
        "label_zh": "客观元素编撰",
        "description": "Admin 批量采集客观世界条目（非故事主题）。",
        "provider": None,
        "model": None,
        "system_prompt": ELEMENT_SYSTEM_PROMPT,
        "user_prompt_template": DEFAULT_USER_TEMPLATE,
        "max_tokens": 8192,
        "timeout_seconds": 300,
        "temperature": None,
        "placeholders_json": _ph(
            ("user_payload", "代码组装的元素生成用户 JSON（含 age_stage/count/子类等）"),
        ),
        "enabled": True,
    },
    "catalog_kernel_gen": {
        "label_zh": "发展内核编撰",
        "description": "Admin 批量采集发展性主题轴内核（非情节种子）。",
        "provider": None,
        "model": None,
        "system_prompt": KERNEL_SYSTEM_PROMPT,
        "user_prompt_template": DEFAULT_USER_TEMPLATE,
        "max_tokens": 8192,
        "timeout_seconds": 300,
        "temperature": None,
        "placeholders_json": _ph(
            ("user_payload", "代码组装的内核生成用户 JSON（含 age_stage/axis/count 等）"),
        ),
        "enabled": True,
    },
}


@dataclass(frozen=True)
class AgentConfig:
    id: str
    label_zh: str
    description: str
    provider: str | None
    model: str | None
    system_prompt: str
    user_prompt_template: str
    max_tokens: int | None
    timeout_seconds: int | None
    temperature: float | None
    placeholders: list[dict[str, str]]
    enabled: bool
    from_db: bool


def resolve_temperature(value: float | None) -> float:
    if value is None:
        return DEFAULT_TEMPERATURE
    return max(0.0, min(2.0, float(value)))


def render_template(template: str, variables: dict[str, Any]) -> str:
    """Replace {{name}} with str(variables[name]); missing → empty + warning."""

    def _repl(match: re.Match[str]) -> str:
        key = match.group(1)
        if key not in variables or variables[key] is None:
            logger.warning("llm_agent placeholder missing: %s", key)
            return ""
        val = variables[key]
        if isinstance(val, (dict, list)):
            return json.dumps(val, ensure_ascii=False)
        return str(val)

    return _PLACEHOLDER_RE.sub(_repl, template or "")


def code_default_config(agent_id: str) -> AgentConfig:
    if agent_id not in CODE_DEFAULTS:
        raise ValueError(f"unknown agent id: {agent_id}")
    d = CODE_DEFAULTS[agent_id]
    try:
        placeholders = json.loads(d["placeholders_json"] or "[]")
    except json.JSONDecodeError:
        placeholders = []
    return AgentConfig(
        id=agent_id,
        label_zh=d["label_zh"],
        description=d["description"],
        provider=d.get("provider"),
        model=d.get("model"),
        system_prompt=d["system_prompt"],
        user_prompt_template=d.get("user_prompt_template") or DEFAULT_USER_TEMPLATE,
        max_tokens=d.get("max_tokens"),
        timeout_seconds=d.get("timeout_seconds"),
        temperature=d.get("temperature"),
        placeholders=placeholders if isinstance(placeholders, list) else [],
        enabled=True,
        from_db=False,
    )


def _row_to_config(row: LlmAgent) -> AgentConfig:
    try:
        placeholders = json.loads(row.placeholders_json or "[]")
    except json.JSONDecodeError:
        placeholders = []
    return AgentConfig(
        id=row.id,
        label_zh=row.label_zh or row.id,
        description=row.description or "",
        provider=(row.provider or None),
        model=(row.model or None),
        system_prompt=row.system_prompt or "",
        user_prompt_template=row.user_prompt_template or DEFAULT_USER_TEMPLATE,
        max_tokens=row.max_tokens,
        timeout_seconds=row.timeout_seconds,
        temperature=getattr(row, "temperature", None),
        placeholders=placeholders if isinstance(placeholders, list) else [],
        enabled=bool(row.enabled),
        from_db=True,
    )


async def get_agent(db: AsyncSession | None, agent_id: str) -> AgentConfig:
    """DB row if present and enabled; otherwise code fallback."""
    if agent_id not in CODE_DEFAULTS:
        raise ValueError(f"unknown agent id: {agent_id}")
    fallback = code_default_config(agent_id)
    if db is None:
        return fallback
    row = await db.get(LlmAgent, agent_id)
    if row is None or not row.enabled:
        return fallback
    cfg = _row_to_config(row)
    # Empty prompts → unsafe; fall back.
    if not (cfg.system_prompt or "").strip():
        logger.warning("llm_agent %s has empty system_prompt; using code default", agent_id)
        return fallback
    return cfg


async def get_agent_stored(db: AsyncSession, agent_id: str) -> AgentConfig:
    """Admin/lab editing: return the DB row as stored (even if disabled).

    Runtime story pipeline must keep using get_agent (enabled + non-empty gate).
    Missing row → code default with from_db=False.
    """
    if agent_id not in CODE_DEFAULTS:
        raise ValueError(f"unknown agent id: {agent_id}")
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        return code_default_config(agent_id)
    return _row_to_config(row)


async def get_agent_standalone(agent_id: str) -> AgentConfig:
    """Load agent using a short-lived session (for pipeline without injected db)."""
    async with SessionLocal() as db:
        return await get_agent(db, agent_id)


def build_chat_messages(
    agent: AgentConfig,
    *,
    user_payload: str,
    extra_vars: dict[str, Any] | None = None,
) -> tuple[str, str]:
    vars_: dict[str, Any] = {"user_payload": user_payload}
    if extra_vars:
        vars_.update(extra_vars)
    system = render_template(agent.system_prompt, vars_)
    user = render_template(agent.user_prompt_template, vars_)
    return system, user


async def seed_llm_agents_if_missing(db: AsyncSession) -> int:
    """Insert missing agent rows only. Never overwrite Admin-saved prompts on restart.

    To restore code defaults, use reset_agent_to_code_default (Admin reset).
    """
    inserted = 0
    for agent_id, d in CODE_DEFAULTS.items():
        existing = await db.get(LlmAgent, agent_id)
        if existing is not None:
            continue
        db.add(
            LlmAgent(
                id=agent_id,
                label_zh=d["label_zh"],
                description=d["description"],
                provider=d.get("provider"),
                model=d.get("model"),
                system_prompt=d["system_prompt"],
                user_prompt_template=d.get("user_prompt_template") or DEFAULT_USER_TEMPLATE,
                max_tokens=d.get("max_tokens"),
                timeout_seconds=d.get("timeout_seconds"),
                temperature=d.get("temperature"),
                placeholders_json=d["placeholders_json"],
                enabled=True,
            )
        )
        inserted += 1
    if inserted:
        await db.commit()
    logger.info("llm_agents seed inserted=%s", inserted)
    return inserted


async def reset_agent_to_code_default(
    db: AsyncSession,
    agent_id: str,
    *,
    created_by: str = "",
    note: str = "",
) -> LlmAgent:
    if agent_id not in CODE_DEFAULTS:
        raise ValueError(f"unknown agent id: {agent_id}")
    d = CODE_DEFAULTS[agent_id]
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        row = LlmAgent(id=agent_id)
        db.add(row)
        await db.flush()
    else:
        # Preserve pre-reset text as history when this agent has no versions yet.
        await ensure_baseline_version_if_needed(db, row, created_by=created_by)

    row.label_zh = d["label_zh"]
    row.description = d["description"]
    row.provider = d.get("provider")
    row.model = d.get("model")
    row.system_prompt = d["system_prompt"]
    row.user_prompt_template = d.get("user_prompt_template") or DEFAULT_USER_TEMPLATE
    row.max_tokens = d.get("max_tokens")
    row.timeout_seconds = d.get("timeout_seconds")
    row.temperature = d.get("temperature")
    row.placeholders_json = d["placeholders_json"]
    row.enabled = True
    await snapshot_agent_version(
        db,
        row,
        source="reset_code",
        created_by=created_by,
        note=note or "恢复代码默认",
    )
    await db.commit()
    await db.refresh(row)
    return row


async def next_version_no(db: AsyncSession, agent_id: str) -> int:
    result = await db.execute(
        select(func.coalesce(func.max(LlmAgentVersion.version), 0)).where(
            LlmAgentVersion.agent_id == agent_id
        )
    )
    return int(result.scalar_one() or 0) + 1


def _version_fields_from_agent(row: LlmAgent) -> dict[str, Any]:
    return {
        "system_prompt": row.system_prompt or "",
        "user_prompt_template": row.user_prompt_template or DEFAULT_USER_TEMPLATE,
        "temperature": row.temperature,
        "max_tokens": row.max_tokens,
        "timeout_seconds": row.timeout_seconds,
    }


async def snapshot_agent_version(
    db: AsyncSession,
    row: LlmAgent,
    *,
    source: str,
    created_by: str = "",
    note: str = "",
) -> LlmAgentVersion:
    """Insert a version row matching the agent's current prompt/generation fields."""
    ver = await next_version_no(db, row.id)
    snap = LlmAgentVersion(
        agent_id=row.id,
        version=ver,
        note=(note or "")[:256],
        source=source,
        created_by=(created_by or "")[:128],
        **_version_fields_from_agent(row),
    )
    db.add(snap)
    await db.flush()
    return snap


async def ensure_baseline_version_if_needed(
    db: AsyncSession,
    row: LlmAgent,
    *,
    created_by: str = "",
) -> LlmAgentVersion | None:
    """On first versioned save: record the pre-edit row as v1 so history is not lost."""
    result = await db.execute(
        select(func.count())
        .select_from(LlmAgentVersion)
        .where(LlmAgentVersion.agent_id == row.id)
    )
    if int(result.scalar_one() or 0) > 0:
        return None
    return await snapshot_agent_version(
        db,
        row,
        source="admin_save",
        created_by=created_by,
        note="保存前基线",
    )


async def apply_prompt_fields_and_version(
    db: AsyncSession,
    row: LlmAgent,
    *,
    system_prompt: str | None = None,
    user_prompt_template: str | None = None,
    temperature: float | None = None,
    max_tokens: int | None = None,
    timeout_seconds: int | None = None,
    clear_temperature: bool = False,
    clear_max_tokens: bool = False,
    clear_timeout_seconds: bool = False,
    source: str,
    created_by: str = "",
    note: str = "",
) -> LlmAgentVersion:
    """Baseline if needed → apply prompt/gen fields → insert version. Caller commits."""
    await ensure_baseline_version_if_needed(db, row, created_by=created_by)

    if system_prompt is not None:
        row.system_prompt = system_prompt
    if user_prompt_template is not None:
        row.user_prompt_template = user_prompt_template
    if clear_temperature:
        row.temperature = None
    elif temperature is not None:
        row.temperature = temperature
    if clear_max_tokens:
        row.max_tokens = None
    elif max_tokens is not None:
        row.max_tokens = max_tokens
    if clear_timeout_seconds:
        row.timeout_seconds = None
    elif timeout_seconds is not None:
        row.timeout_seconds = timeout_seconds

    return await snapshot_agent_version(
        db, row, source=source, created_by=created_by, note=note
    )


async def restore_agent_version(
    db: AsyncSession,
    agent_id: str,
    version: int,
    *,
    created_by: str = "",
    note: str = "",
) -> LlmAgent:
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        raise ValueError("Agent not found")
    result = await db.execute(
        select(LlmAgentVersion).where(
            LlmAgentVersion.agent_id == agent_id,
            LlmAgentVersion.version == version,
        )
    )
    snap = result.scalar_one_or_none()
    if snap is None:
        raise ValueError("Version not found")

    await ensure_baseline_version_if_needed(db, row, created_by=created_by)
    row.system_prompt = snap.system_prompt or ""
    row.user_prompt_template = snap.user_prompt_template or DEFAULT_USER_TEMPLATE
    row.temperature = snap.temperature
    row.max_tokens = snap.max_tokens
    row.timeout_seconds = snap.timeout_seconds
    await snapshot_agent_version(
        db,
        row,
        source="restore",
        created_by=created_by,
        note=note or f"回滚至 v{version}",
    )
    await db.commit()
    await db.refresh(row)
    return row


def agent_to_dict(cfg: AgentConfig) -> dict[str, Any]:
    return {
        "id": cfg.id,
        "label_zh": cfg.label_zh,
        "description": cfg.description,
        "provider": cfg.provider,
        "model": cfg.model,
        "system_prompt": cfg.system_prompt,
        "user_prompt_template": cfg.user_prompt_template,
        "max_tokens": cfg.max_tokens,
        "timeout_seconds": cfg.timeout_seconds,
        "temperature": cfg.temperature,
        "placeholders": cfg.placeholders,
        "enabled": cfg.enabled,
        "from_db": cfg.from_db,
    }
