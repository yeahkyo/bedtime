"""LLM batch generation of objective story-element knowledge for admin review."""

from __future__ import annotations

import json
import logging
import re
from typing import Any

import httpx
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.story_element import StoryElement, StoryElementCategory, StoryElementSubcategory
from app.services.element_age_stages import (
    AGE_STAGE_IDS,
    AGE_STAGES,
    list_age_stages,
    suggested_counts,
)

logger = logging.getLogger(__name__)

ELEMENT_GEN_PROVIDERS = ("doubao", "openai", "deepseek", "mock")
GEN_TIMEOUT_SECONDS = 300.0
GEN_MAX_TOKENS = 8192
# Soft inventory target per subcategory across all stages (ops guidance).
DEFAULT_SUBCATEGORY_TARGET = 100

_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,62}$")

SYSTEM_PROMPT = """你是儿童发展心理学与百科知识编撰者（不是童话编剧）。

任务：为指定「发展年龄阶段」与「知识子类」撰写客观认知条目。
这些条目只提供事实基础，供系统日后轻触进睡前故事——条目本身不是故事主题、不是寓意、不是价值观口号。

硬性要求：
1. 只输出 JSON 对象：{"items":[...]}，不要 markdown。
2. 每条字段仅：id、name、description（字符串）。
3. name：客观事物/现象名称（如「影子」「露珠」），禁止故事标题腔、拟人标题、道德口号。
4. description：中性、可核验的介绍，适合该发展阶段儿童「知晓/接触」；可含可观察特征，禁止说教、隐喻点题、人生哲理、故事情节建议。
5. id 格式为「子类前缀_三位数字」，如 plg_001；本批内唯一。
6. 不要输出年龄、分类、哲学、寓意、execution_hint 等额外字段。
"""


def build_element_gen_messages(
    *,
    category_label: str,
    subcategory_label: str,
    id_prefix: str,
    generation_brief: str,
    age_stage: str,
    existing_names: list[str],
    count: int,
) -> tuple[str, str]:
    stage = AGE_STAGES[age_stage]
    avoid = existing_names[:80]
    user = {
        "task": f"生成 {count} 条客观认知条目（非故事素材包）",
        "category": category_label,
        "subcategory": subcategory_label,
        "id_prefix": id_prefix,
        "generation_brief": generation_brief,
        "age_stage": {
            "id": stage["id"],
            "label": stage["label_zh"],
            "years": f"{stage['min_age_years']}–{stage['max_age_years']}",
            "developmental_focus": stage["theory_hint"],
        },
        "count": count,
        "avoid_duplicate_names": avoid,
        "output_schema": {
            "items": [
                {
                    "id": f"{id_prefix}_001",
                    "name": "客观名称",
                    "description": "中性发展适宜的客观介绍",
                }
            ]
        },
        "forbidden": [
            "故事寓意",
            "人生哲理",
            "说教结尾",
            "情节/角色建议",
            "把条目写成今晚故事主题",
        ],
    }
    return SYSTEM_PROMPT, json.dumps(user, ensure_ascii=False)


def parse_element_gen_json(raw: str) -> list[dict[str, Any]]:
    text = (raw or "").strip()
    if not text:
        raise ValueError("empty LLM response")
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\s*```$", "", text)
    data = json.loads(text)
    if isinstance(data, list):
        items = data
    elif isinstance(data, dict):
        items = data.get("items") or data.get("elements")
        if items is None and all(k in data for k in ("id", "name", "description")):
            items = [data]
        # Legacy keys from older prompt
        if items is None and all(k in data for k in ("id", "topic", "fact")):
            items = [data]
        if not isinstance(items, list):
            raise ValueError("JSON must contain items[] array")
    else:
        raise ValueError("JSON must be object or array")
    return [x for x in items if isinstance(x, dict)]


def _allocate_id(prefix: str, used: set[str], preferred: str | None) -> str:
    if preferred and _ID_RE.match(preferred) and preferred not in used:
        return preferred
    n = 1
    while True:
        cand = f"{prefix}_{n:03d}"
        if cand not in used:
            return cand
        n += 1
        if n > 9999:
            raise ValueError("exhausted id space for prefix")


def normalize_to_rows(
    items: list[dict[str, Any]],
    *,
    category_id: str,
    subcategory_id: str,
    id_prefix: str,
    age_stage: str,
    existing_ids: set[str],
) -> list[dict[str, Any]]:
    """Map LLM items → DB rows; new rows default enabled for silent recommend."""
    if age_stage not in AGE_STAGES:
        raise ValueError(f"invalid age_stage: {age_stage}")
    used = set(existing_ids)
    rows: list[dict[str, Any]] = []
    for raw in items:
        name = str(raw.get("name") or raw.get("topic") or raw.get("title") or "").strip()
        description = str(raw.get("description") or raw.get("fact") or "").strip()
        if not description and isinstance(raw.get("cognition"), dict):
            description = str(raw["cognition"].get("fact") or "").strip()
        if not name or not description:
            continue
        preferred = str(raw.get("id") or "").strip().lower()
        if preferred and (
            not preferred.startswith(f"{id_prefix}_") or not _ID_RE.match(preferred)
        ):
            preferred = None
        eid = _allocate_id(id_prefix, used, preferred)
        used.add(eid)
        rows.append(
            {
                "id": eid,
                "category_id": category_id,
                "subcategory_id": subcategory_id,
                "name": name[:256],
                "description": description,
                "age_stage": age_stage,
                "enabled": True,
            }
        )
    return rows


def generate_defaults() -> dict[str, Any]:
    s = get_settings()
    return {
        "providers": list(ELEMENT_GEN_PROVIDERS),
        "defaults": {
            "doubao": s.ark_model,
            "openai": s.openai_model,
            "deepseek": s.deepseek_model,
            "mock": "mock",
        },
        "age_stages": list_age_stages(),
        "subcategory_target_total": DEFAULT_SUBCATEGORY_TARGET,
        "stage_targets": suggested_counts(DEFAULT_SUBCATEGORY_TARGET),
    }


async def inventory_for_subcategory(
    db: AsyncSession, subcategory_id: str
) -> dict[str, Any]:
    rows = (
        await db.execute(
            select(StoryElement.age_stage, func.count())
            .where(StoryElement.subcategory_id == subcategory_id)
            .group_by(StoryElement.age_stage)
        )
    ).all()
    counts = {sid: 0 for sid in AGE_STAGE_IDS}
    for stage, n in rows:
        if stage in counts:
            counts[str(stage)] = int(n)
    targets = suggested_counts(DEFAULT_SUBCATEGORY_TARGET)
    gaps = {sid: max(0, targets[sid] - counts[sid]) for sid in AGE_STAGE_IDS}
    return {
        "subcategory_id": subcategory_id,
        "target_total": DEFAULT_SUBCATEGORY_TARGET,
        "targets": targets,
        "counts": counts,
        "gaps": gaps,
        "total": sum(counts.values()),
    }


async def chat_for_elements(
    provider: str,
    model: str,
    system: str,
    user: str,
    *,
    timeout: float = GEN_TIMEOUT_SECONDS,
    max_tokens: int = GEN_MAX_TOKENS,
    temperature: float | None = None,
) -> str:
    name = (provider or "").strip().lower()
    if name not in ELEMENT_GEN_PROVIDERS:
        raise ValueError(f"Unsupported provider: {provider}")
    if name == "mock":
        return _mock_elements_json(user)
    model_id = (model or "").strip()
    if not model_id:
        raise ValueError("model is required")
    settings = get_settings()
    common = dict(
        model=model_id,
        system=system,
        user=user,
        timeout=timeout,
        max_tokens=max_tokens,
        temperature=temperature,
    )
    if name == "deepseek":
        return await _openai_compat_chat(
            base_url=(settings.deepseek_base_url or "https://api.deepseek.com").rstrip("/"),
            api_key=settings.deepseek_api_key,
            label="DeepSeek",
            extra_body={
                "thinking": {"type": "disabled"},
                "response_format": {"type": "json_object"},
            },
            **common,
        )
    if name == "openai":
        return await _openai_compat_chat(
            base_url="https://api.openai.com/v1",
            api_key=settings.openai_api_key,
            label="OpenAI",
            extra_body={"response_format": {"type": "json_object"}},
            **common,
        )
    return await _openai_compat_chat(
        base_url=(settings.ark_base_url or "").rstrip("/"),
        api_key=settings.ark_api_key,
        label="Ark",
        extra_body={},
        **common,
    )


def _mock_elements_json(user_json: str) -> str:
    try:
        payload = json.loads(user_json)
        count = int(payload.get("count") or 3)
        prefix = str(payload.get("id_prefix") or "plg")
        sub = str(payload.get("subcategory") or "子类")
        stage = (payload.get("age_stage") or {}).get("id") or "preschool_3_5"
    except Exception:
        count, prefix, sub, stage = 3, "plg", "子类", "preschool_3_5"
    count = max(1, min(count, 10))
    items = [
        {
            "id": f"{prefix}_{i:03d}",
            "name": f"模拟事物{i}",
            "description": f"关于{sub}的客观介绍（阶段 {stage}）条目 {i}。",
        }
        for i in range(1, count + 1)
    ]
    return json.dumps({"items": items}, ensure_ascii=False)


async def _openai_compat_chat(
    *,
    base_url: str,
    api_key: str | None,
    model: str,
    system: str,
    user: str,
    timeout: float,
    max_tokens: int,
    label: str,
    extra_body: dict[str, Any],
    temperature: float | None = None,
) -> str:
    from app.services.llm_agents import resolve_temperature

    if not api_key:
        raise RuntimeError(f"{label} API key is not set")
    body: dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "max_tokens": max_tokens,
        "temperature": resolve_temperature(temperature),
        **extra_body,
    }
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(
                f"{base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
    except httpx.TimeoutException as exc:
        raise RuntimeError(f"{label} element gen timed out after {int(timeout)}s") from exc
    if resp.status_code >= 400:
        raise RuntimeError(f"{label} element gen failed {resp.status_code}: {resp.text[:800]}")
    choice = resp.json()["choices"][0]
    content = (choice.get("message") or {}).get("content") or ""
    finish = choice.get("finish_reason")
    if not str(content).strip():
        raise RuntimeError(f"{label} element gen empty content (finish_reason={finish})")
    return content


async def run_element_generation(
    db: AsyncSession,
    *,
    subcategory_id: str,
    age_stage: str,
    provider: str,
    model: str,
    count: int,
) -> dict[str, Any]:
    if age_stage not in AGE_STAGES:
        raise ValueError(
            f"age_stage must be one of {', '.join(AGE_STAGE_IDS)}"
        )
    sub = await db.get(StoryElementSubcategory, subcategory_id)
    if sub is None:
        raise ValueError("subcategory not found")
    if not (sub.generation_brief or "").strip() or not (sub.id_prefix or "").strip():
        raise ValueError("subcategory is not in canonical generate taxonomy")
    cat = await db.get(StoryElementCategory, sub.category_id)
    if cat is None:
        raise ValueError("category not found")

    existing_rows = (
        await db.execute(
            select(StoryElement.id, StoryElement.name).where(
                StoryElement.subcategory_id == subcategory_id
            )
        )
    ).all()
    existing_ids = {str(r[0]) for r in existing_rows}
    existing_names = [str(r[1]) for r in existing_rows if r[1]]

    _sys, user_payload = build_element_gen_messages(
        category_label=cat.label_zh or cat.id,
        subcategory_label=sub.label_zh or sub.id,
        id_prefix=sub.id_prefix or "el",
        generation_brief=sub.generation_brief or "",
        age_stage=age_stage,
        existing_names=existing_names,
        count=count,
    )
    from app.services.llm_agents import build_chat_messages, get_agent

    agent = await get_agent(db, "catalog_element_gen")
    system, user = build_chat_messages(
        agent,
        user_payload=user_payload,
    )
    # Caller provider/model win; agent fills gaps for tokens/timeout only.
    timeout = float(agent.timeout_seconds or GEN_TIMEOUT_SECONDS)
    max_tokens = int(agent.max_tokens or GEN_MAX_TOKENS)
    raw = await chat_for_elements(
        provider,
        model,
        system,
        user,
        timeout=timeout,
        max_tokens=max_tokens,
        temperature=agent.temperature,
    )
    parsed = parse_element_gen_json(raw)
    rows = normalize_to_rows(
        parsed,
        category_id=sub.category_id,
        subcategory_id=sub.id,
        id_prefix=sub.id_prefix or "el",
        age_stage=age_stage,
        existing_ids=existing_ids,
    )
    if not rows:
        raise ValueError("no valid elements parsed from LLM response")

    created = 0
    updated = 0
    for item in rows:
        row = await db.get(StoryElement, item["id"])
        if row is None:
            db.add(
                StoryElement(
                    id=item["id"],
                    category_id=item["category_id"],
                    subcategory_id=item["subcategory_id"],
                    name=item["name"],
                    description=item["description"],
                    age_stage=item["age_stage"],
                    enabled=True,
                )
            )
            created += 1
        else:
            row.category_id = item["category_id"]
            row.subcategory_id = item["subcategory_id"]
            row.name = item["name"]
            row.description = item["description"]
            row.age_stage = item["age_stage"]
            # Preserve admin enable/disable on regenerate.
            updated += 1
    await db.commit()
    inv = await inventory_for_subcategory(db, subcategory_id)
    preview = [
        {
            "id": r["id"],
            "name": r["name"],
            "age_stage": r["age_stage"],
            "enabled": True,
        }
        for r in rows[:20]
    ]
    return {
        "created": created,
        "updated": updated,
        "total": created + updated,
        "provider": provider.strip().lower(),
        "model": model.strip() if provider.strip().lower() != "mock" else "mock",
        "age_stage": age_stage,
        "items_preview": preview,
        "inventory": inv,
    }
