"""LLM batch generation of developmental story kernels for admin review."""

from __future__ import annotations

import json
import logging
import re
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.story_kernel import StoryKernel
from app.providers.story_prompt import FOCUS_BEAT_MAP
from app.services.element_age_stages import (
    AGE_STAGE_IDS,
    AGE_STAGES,
    list_age_stages,
)
from app.services.element_generation import (
    ELEMENT_GEN_PROVIDERS,
    GEN_MAX_TOKENS,
    GEN_TIMEOUT_SECONDS,
    _openai_compat_chat,
)
from app.services.story_kernels import AXIS_LABELS_ZH

logger = logging.getLogger(__name__)

_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,62}$")

STAGE_CODE = {
    "toddler_2_3": "t23",
    "preschool_3_5": "p35",
    "early_school_6_8": "e68",
    "late_school_9_12": "l912",
}

# Developmental axes with theory-informed generation briefs (Erikson / early childhood).
KERNEL_AXES: dict[str, dict[str, Any]] = {
    "security": {
        "id": "security",
        "label_zh": "安全感",
        "default_focus_id": "secure_presence",
        "theory_brief": (
            "依恋与安全基地（Bowlby/Ainsworth）；知道重要的人/物/声音还在。"
            "条目强调可被接住的在场感，禁止「不许怕」类训诫。"
        ),
    },
    "courage": {
        "id": "courage",
        "label_zh": "勇气",
        "default_focus_id": "tiny_brave",
        "theory_brief": (
            "主动探索与小小试探（Erikson: 主动 vs 内疚；学龄初勤奋感）。"
            "强调「试一下就被接住」，禁止英雄式勇敢口号。"
        ),
    },
    "self": {
        "id": "self",
        "label_zh": "自我与自主",
        "default_focus_id": "gentle_agency",
        "theory_brief": (
            "自主与能动性（Erikson: 自主 vs 羞怯）；做一件很小的事、小小决定。"
            "禁止「独立才乖」类评价。"
        ),
    },
    "emotion": {
        "id": "emotion",
        "label_zh": "情绪感受",
        "default_focus_id": "emotion_held",
        "theory_brief": (
            "情绪被看见与命名（情绪教练）；身体感受可点到为止。"
            "禁止分析心理、禁止「不许哭」。"
        ),
    },
    "belonging": {
        "id": "belonging",
        "label_zh": "归属与同伴",
        "default_focus_id": "friend_repair",
        "theory_brief": (
            "同伴关系与修复；给对方一点空间、小摩擦后和好。"
            "双方都不被贬低；禁止道德审判。"
        ),
    },
    "curiosity": {
        "id": "curiosity",
        "label_zh": "好奇",
        "default_focus_id": "curious_cause",
        "theory_brief": (
            "认知好奇与简单因果（Piaget 前运算→具体运算）。"
            "轻轻弄明白一点即可；禁止课堂讲解。"
        ),
    },
    "empathy": {
        "id": "empathy",
        "label_zh": "理解他人",
        "default_focus_id": "mentalize_light",
        "theory_brief": (
            "他人视角萌芽（心智化轻度）；别人可能有不一样的小心思，仍友善收场。"
            "禁止说教「要懂事」。"
        ),
    },
    "fairness": {
        "id": "fairness",
        "label_zh": "公平",
        "default_focus_id": "fair_turn",
        "theory_brief": (
            "轮流与公平萌芽；可观察的「轮到谁」。"
            "禁止抽象正义课。"
        ),
    },
    "rest": {
        "id": "rest",
        "label_zh": "安静与休息",
        "default_focus_id": "wind_down",
        "theory_brief": (
            "唤醒水平下降与睡前过渡；玩过之后慢慢安静。"
            "禁止催睡命令。"
        ),
    },
    "body": {
        "id": "body",
        "label_zh": "身体节奏",
        "default_focus_id": "body_rhythm",
        "theory_brief": (
            "身体感觉与节律（拥抱、呼吸变慢、眼皮变沉）。"
            "只描述可感身体线索，不作体能训练指令。"
        ),
    },
}

AXIS_IDS = tuple(KERNEL_AXES.keys())
KNOWN_FOCUS_IDS = frozenset(FOCUS_BEAT_MAP.keys())

SYSTEM_PROMPT = """你是儿童发展心理学顾问（不是品德课老师，也不是童话编剧）。

任务：为指定「发展年龄阶段」与「主题轴」撰写睡前故事「内核」条目。
内核 = 一般性的发展主题轴（安全感、勇气、好奇等），作为故事的轻柔引力——
不是情节种子，不是道德口号，不是课堂主题。

硬性要求：
1. 只输出 JSON 对象：{"items":[...]}，不要 markdown。
2. 每条字段仅：id、axis、name、soft_guidance、focus_id（字符串）。
3. name：短中文主题名（如「小小试探」「安心在场」），禁止故事标题腔、禁止「要善良」口号。
4. soft_guidance：说明如何在该年龄「轻触」为愿望或关系走向；必须强调禁止点题说教/道德收尾。
5. axis：必须是给定主题轴 id（英文 snake_case）。
6. focus_id：必须从给定 allowlist 中选择（用于对接叙事节拍）。
7. id 格式为「前缀_三位数字」，如 cou_p35_001；本批内唯一。
8. 不要输出情节建议、角色名、哲学金句、values 列表。
"""


def list_kernel_axes() -> list[dict[str, Any]]:
    return [
        {
            "id": m["id"],
            "label_zh": m["label_zh"],
            "default_focus_id": m["default_focus_id"],
            "theory_brief": m["theory_brief"],
        }
        for m in KERNEL_AXES.values()
    ]


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
        "axes": list_kernel_axes(),
        "focus_ids": sorted(KNOWN_FOCUS_IDS),
    }


def build_kernel_gen_messages(
    *,
    age_stage: str,
    axis: str,
    existing_names: list[str],
    count: int,
) -> tuple[str, str]:
    if age_stage not in AGE_STAGES:
        raise ValueError(f"invalid age_stage: {age_stage}")
    if axis not in KERNEL_AXES:
        raise ValueError(f"axis must be one of {', '.join(AXIS_IDS)}")
    stage = AGE_STAGES[age_stage]
    axis_meta = KERNEL_AXES[axis]
    code = STAGE_CODE.get(age_stage, "x")
    prefix = f"{axis[:3]}_{code}"
    allow_focus = sorted(KNOWN_FOCUS_IDS)
    user = {
        "task": f"生成 {count} 条发展性故事内核（一般主题轴，非情节）",
        "developmental_framework": [
            "Erikson 心理社会发展阶段（自主/主动/勤奋等）",
            "依恋与安全基地",
            "情绪被看见（轻度）",
            "Piaget 认知阶段仅作适龄提示，勿写成教案",
        ],
        "age_stage": {
            "id": stage["id"],
            "label": stage["label_zh"],
            "years": f"{stage['min_age_years']}–{stage['max_age_years']}",
            "theory_hint": stage["theory_hint"],
        },
        "axis": {
            "id": axis_meta["id"],
            "label_zh": axis_meta["label_zh"],
            "theory_brief": axis_meta["theory_brief"],
            "preferred_focus_id": axis_meta["default_focus_id"],
        },
        "id_prefix": prefix,
        "focus_id_allowlist": allow_focus,
        "count": count,
        "avoid_duplicate_names": existing_names[:80],
        "output_schema": {
            "items": [
                {
                    "id": f"{prefix}_001",
                    "axis": axis,
                    "name": "短主题名",
                    "soft_guidance": "该年龄如何轻触；含禁止说教提示",
                    "focus_id": axis_meta["default_focus_id"],
                }
            ]
        },
        "forbidden": [
            "品德口号（要善良/要懂事）",
            "具体故事情节或角色",
            "课堂总结式点题",
            "与客观百科条目混淆",
        ],
    }
    return SYSTEM_PROMPT, json.dumps(user, ensure_ascii=False)


def parse_kernel_gen_json(raw: str) -> list[dict[str, Any]]:
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
        items = data.get("items") or data.get("kernels")
        if items is None and all(k in data for k in ("id", "name", "soft_guidance")):
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
    age_stage: str,
    axis: str,
    existing_ids: set[str],
) -> list[dict[str, Any]]:
    if age_stage not in AGE_STAGES:
        raise ValueError(f"invalid age_stage: {age_stage}")
    if axis not in KERNEL_AXES:
        raise ValueError(f"invalid axis: {axis}")
    axis_meta = KERNEL_AXES[axis]
    code = STAGE_CODE.get(age_stage, "x")
    prefix = f"{axis[:3]}_{code}"
    used = set(existing_ids)
    rows: list[dict[str, Any]] = []
    for raw in items:
        name = str(raw.get("name") or raw.get("title") or "").strip()
        guidance = str(
            raw.get("soft_guidance") or raw.get("guidance") or raw.get("how") or ""
        ).strip()
        if not name or not guidance:
            continue
        if "禁止" not in guidance and "不要" not in guidance:
            guidance = guidance.rstrip("。") + "。禁止点题说教或道德口号收尾。"
        fid = str(raw.get("focus_id") or "").strip()
        if fid not in KNOWN_FOCUS_IDS:
            fid = axis_meta["default_focus_id"]
        preferred = str(raw.get("id") or "").strip().lower()
        if preferred and (
            not preferred.startswith(f"{prefix}_") or not _ID_RE.match(preferred)
        ):
            preferred = None
        kid = _allocate_id(prefix, used, preferred)
        used.add(kid)
        rows.append(
            {
                "id": kid,
                "axis": axis,
                "name": name[:128],
                "soft_guidance": guidance,
                "age_stage": age_stage,
                "focus_id": fid,
                "enabled": False,
                "sort_order": 500,
            }
        )
    return rows


def _mock_kernels_json(user_json: str) -> str:
    try:
        payload = json.loads(user_json)
        count = int(payload.get("count") or 3)
        prefix = str(payload.get("id_prefix") or "cou_p35")
        axis = (payload.get("axis") or {}).get("id") or "courage"
        focus = (payload.get("axis") or {}).get("preferred_focus_id") or "tiny_brave"
        label = (payload.get("axis") or {}).get("label_zh") or "勇气"
    except Exception:
        count, prefix, axis, focus, label = 3, "cou_p35", "courage", "tiny_brave", "勇气"
    count = max(1, min(count, 10))
    items = [
        {
            "id": f"{prefix}_{i:03d}",
            "axis": axis,
            "name": f"模拟{label}{i}",
            "soft_guidance": (
                f"以发展适宜方式轻触「{label}」轴；禁止点题说教或道德口号收尾。"
            ),
            "focus_id": focus,
        }
        for i in range(1, count + 1)
    ]
    return json.dumps({"items": items}, ensure_ascii=False)


async def chat_for_kernels(
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
        return _mock_kernels_json(user)
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


async def run_kernel_generation(
    db: AsyncSession,
    *,
    age_stage: str,
    axis: str,
    provider: str,
    model: str,
    count: int,
) -> dict[str, Any]:
    if age_stage not in AGE_STAGES:
        raise ValueError(f"age_stage must be one of {', '.join(AGE_STAGE_IDS)}")
    if axis not in KERNEL_AXES:
        raise ValueError(f"axis must be one of {', '.join(AXIS_IDS)}")

    existing_rows = (
        await db.execute(
            select(StoryKernel.id, StoryKernel.name).where(
                StoryKernel.age_stage == age_stage,
                StoryKernel.axis == axis,
            )
        )
    ).all()
    existing_ids = {str(r[0]) for r in existing_rows}
    existing_names = [str(r[1]) for r in existing_rows if r[1]]

    _sys, user_payload = build_kernel_gen_messages(
        age_stage=age_stage,
        axis=axis,
        existing_names=existing_names,
        count=count,
    )
    from app.services.llm_agents import build_chat_messages, get_agent

    agent = await get_agent(db, "catalog_kernel_gen")
    system, user = build_chat_messages(
        agent,
        user_payload=user_payload,
    )
    timeout = float(agent.timeout_seconds or GEN_TIMEOUT_SECONDS)
    max_tokens = int(agent.max_tokens or GEN_MAX_TOKENS)
    raw = await chat_for_kernels(
        provider,
        model,
        system,
        user,
        timeout=timeout,
        max_tokens=max_tokens,
        temperature=agent.temperature,
    )
    parsed = parse_kernel_gen_json(raw)
    rows = normalize_to_rows(
        parsed,
        age_stage=age_stage,
        axis=axis,
        existing_ids=existing_ids,
    )
    if not rows:
        raise ValueError("no valid kernels parsed from LLM response")

    created = 0
    updated = 0
    for item in rows:
        row = await db.get(StoryKernel, item["id"])
        if row is None:
            db.add(
                StoryKernel(
                    id=item["id"],
                    axis=item["axis"],
                    name=item["name"],
                    soft_guidance=item["soft_guidance"],
                    age_stage=item["age_stage"],
                    focus_id=item["focus_id"],
                    enabled=False,
                    sort_order=item["sort_order"],
                )
            )
            created += 1
        else:
            row.axis = item["axis"]
            row.name = item["name"]
            row.soft_guidance = item["soft_guidance"]
            row.age_stage = item["age_stage"]
            row.focus_id = item["focus_id"]
            row.enabled = False
            updated += 1
    await db.commit()
    preview = [
        {
            "id": r["id"],
            "name": r["name"],
            "axis": r["axis"],
            "age_stage": r["age_stage"],
            "focus_id": r["focus_id"],
            "enabled": False,
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
        "axis": axis,
        "axis_label": AXIS_LABELS_ZH.get(axis) or KERNEL_AXES[axis]["label_zh"],
        "items_preview": preview,
    }
