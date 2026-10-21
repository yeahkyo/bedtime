"""LLM agent configs: DB-backed prompts with {{placeholder}} rendering + code fallback."""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import SessionLocal
from app.models.llm_agent import LlmAgent
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
        "description": "为软系列设计多集温和大纲（不写正文）。",
        "provider": None,
        "model": None,
        "system_prompt": SERIES_OUTLINE_SYSTEM_PROMPT,
        "user_prompt_template": DEFAULT_USER_TEMPLATE,
        "max_tokens": 4096,
        "timeout_seconds": 180,
        "temperature": None,
        "placeholders_json": _ph(
            ("user_payload", "代码组装的大纲用户 JSON（含 episode_count/theme 等）"),
            ("age_band", "故事年龄档，如 3-5"),
            ("theme", "家长填写的主题"),
            ("child_nickname", "孩子昵称"),
            ("language", "语言代码"),
        ),
        "enabled": True,
    },
    "story_episode_plan": {
        "label_zh": "单集构思",
        "description": "根据 theme/keywords/age/gender/fantasy 产出今晚大纲（不写正文）。",
        "provider": None,
        "model": None,
        "system_prompt": PLAN_SYSTEM_PROMPT,
        "user_prompt_template": DEFAULT_USER_TEMPLATE,
        "max_tokens": 2048,
        "timeout_seconds": 120,
        "temperature": None,
        "placeholders_json": _ph(
            ("user_payload", "代码组装的 plan 用户 JSON（theme/keywords/age/gender/fantasy）"),
            ("age_band", "故事年龄档（内部）"),
            ("theme", "主题"),
            ("child_nickname", "孩子昵称"),
            ("language", "语言代码"),
        ),
        "enabled": True,
    },
    "story_draft": {
        "label_zh": "正文润色",
        "description": "按大纲 JSON 写成可听口语正文。",
        "provider": None,
        "model": None,
        "system_prompt": DRAFT_SYSTEM_PROMPT,
        "user_prompt_template": DEFAULT_USER_TEMPLATE,
        "max_tokens": None,  # duration-based in code
        "timeout_seconds": None,  # duration-based in code
        "temperature": None,
        "placeholders_json": _ph(
            (
                "user_payload",
                "代码组装的 draft 用户 JSON（title/theme/casts/beats/age/gender/dialog/len）",
            ),
            ("age_band", "故事年龄档（内部）"),
            ("theme", "主题"),
            ("child_nickname", "孩子昵称"),
            ("language", "语言代码"),
            ("duration_minutes", "目标时长（分钟）"),
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
            ("user_payload", "代码组装的元素生成用户 JSON"),
            ("age_stage", "发展阶段 id"),
            ("axis_or_subcategory", "子类标签"),
            ("count", "本批条数"),
            ("theory_hint", "发展阶段理论提示"),
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
            ("user_payload", "代码组装的内核生成用户 JSON"),
            ("age_stage", "发展阶段 id"),
            ("axis_or_subcategory", "主题轴 id/标签"),
            ("count", "本批条数"),
            ("theory_hint", "发展阶段或轴的理论提示"),
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
    """Insert missing agent rows; migrate legacy wish/snag plan+draft prompts once."""
    inserted = 0
    migrated = 0
    for agent_id, d in CODE_DEFAULTS.items():
        existing = await db.get(LlmAgent, agent_id)
        if existing is None:
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
            continue
        # One-time migration: old locked-structure / short-key prompts → simplified.
        if agent_id in ("story_episode_plan", "story_draft", "story_series_outline"):
            prompt = getattr(existing, "system_prompt", None) or ""
            user_tpl = getattr(existing, "user_prompt_template", None) or ""
            broken_user_tpl = (
                "{{user_payload}" in user_tpl and "{{user_payload}}" not in user_tpl
            )
            legacy = broken_user_tpl or (
                "wish / snag" in prompt
                or "wish/snag" in prompt
                or "填满 wish" in prompt
                or "按 wish/snag" in prompt
                or "按 beat_roles 顺序与数量写 beats" in prompt
                or "数量与顺序严格等于 story_structure.beat_roles" in prompt
                or "依次愿望、小麻烦、第一次尝试" in prompt
                or "按 beat_roles 顺序各写一条" in prompt
                or "tonight_theme_pref" in prompt
                or "problem_solve" in prompt
                or "daily_slice" in prompt
                or "示例拍" in prompt
                or "beat_hint" in prompt
                or (
                    agent_id == "story_episode_plan"
                    and (
                        "dials.wonder" in prompt
                        or "shape.bmin" in prompt
                        or "shape.how" in prompt
                        or "target_feeling" in prompt
                        or "story_structure" in prompt
                        or "style_dials" in prompt
                        or "story_shape" in prompt
                        or "今晚单集构思" in prompt
                    )
                    and "fantasy:" not in prompt
                    and "fantasy：" not in prompt
                )
                or (
                    agent_id == "story_draft"
                    and (
                        '{"title","body","hook"}' in prompt
                        or "soft_hook" in prompt
                        or "story_plan" in prompt
                        or "style_dials" in prompt
                        or "story_shape" in prompt
                        or "beat.action" in prompt
                        or "dials.wonder" in prompt
                    )
                    and "dialog:" not in prompt
                    and "dialog：" not in prompt
                )
                or (
                    # Simplified prompts missing gender field docs after age→years change.
                    agent_id == "story_episode_plan"
                    and ("fantasy:" in prompt or "fantasy：" in prompt)
                    and "gender" not in prompt.lower()
                )
                or (
                    agent_id == "story_draft"
                    and ("dialog:" in prompt or "dialog：" in prompt)
                    and "gender" not in prompt.lower()
                )
                or (
                    agent_id == "story_series_outline"
                    and (
                        "cast_spine" in prompt
                        or "soft_promise" in prompt
                        or "throughline" in prompt
                        or "style_dials" in prompt
                    )
                )
            )
            if legacy and hasattr(existing, "system_prompt"):
                existing.system_prompt = d["system_prompt"]
                existing.user_prompt_template = (
                    d.get("user_prompt_template") or DEFAULT_USER_TEMPLATE
                )
                migrated += 1
    if inserted or migrated:
        await db.commit()
    logger.info("llm_agents seed inserted=%s migrated_prompts=%s", inserted, migrated)
    return inserted


async def reset_agent_to_code_default(db: AsyncSession, agent_id: str) -> LlmAgent:
    if agent_id not in CODE_DEFAULTS:
        raise ValueError(f"unknown agent id: {agent_id}")
    d = CODE_DEFAULTS[agent_id]
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        row = LlmAgent(id=agent_id)
        db.add(row)
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
