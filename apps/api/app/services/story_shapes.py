"""Story shape catalog: seed, runtime cache, selection for episode plan."""

from __future__ import annotations

import hashlib
import logging
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.story_shape import StoryShape

logger = logging.getLogger(__name__)

# Classic fairy-tale functions. guidance is the LLM instruction (function + bedtime limit).
# beat_min/max is only a count window — not named slots.
LEGACY_SHAPE_IDS = (
    "problem_solve",
    "cumulative",
    "ritual",
    "sensory",
    "contrast",
    "soothe",
    "daily_slice",
)

SHAPE_SEED: list[dict[str, Any]] = [
    {
        "id": "binary_op",
        "label_zh": "二元对立",
        "beat_min": 4,
        "beat_max": 5,
        "effect": "微小张力，最后和解归静",
        "guidance": (
            "二元对立：设定一组温和的对立面（如吵闹对安静、快对慢、白天对晚上），"
            "用习性反差推动情节。"
            "睡前限制：冲突不能是暴力的；最终双方必须和解，或承认彼此的价值；"
            "结局走向和谐与宁静。"
        ),
        "sort_order": 10,
    },
    {
        "id": "depart_return",
        "label_zh": "离家回归",
        "beat_min": 4,
        "beat_max": 6,
        "effect": "一小圈探索，回到温暖处入睡",
        "guidance": (
            "离家-回归：主角出于好奇或微小的心愿离开家，在外面看到美丽的风景，"
            "遇到一点点温和的困难，然后马上开始回归。"
            "睡前限制：外面不能黑暗或危险，不能有野兽；"
            "最终必须回到温暖、柔软的巢穴或床上，带着安全感入睡。"
        ),
        "sort_order": 20,
    },
    {
        "id": "rule_three",
        "label_zh": "三段式重复",
        "beat_min": 3,
        "beat_max": 3,
        "effect": "一次比一次更慢更轻，第三次放松",
        "guidance": (
            "三段式重复：主角连续做三次类似的动作或寻找，一次比一次缓慢、安静、轻柔。"
            "睡前限制：不要第三次剧烈转折；第三次是终于放松下来。"
        ),
        "sort_order": 30,
    },
    {
        "id": "helper",
        "label_zh": "魔法帮手",
        "beat_min": 4,
        "beat_max": 5,
        "effect": "柔和帮手完成睡前仪式后离开",
        "guidance": (
            "魔法帮手：主角遇到一个小小的问题（如睡不着），出现一位温柔的帮手，"
            "用柔和的方式帮忙。"
            "睡前限制：魔法只限发光、白噪音、微风，禁止爆炸与变身；"
            "帮手帮完睡前仪式后悄然离开。"
        ),
        "sort_order": 40,
    },
    {
        "id": "animism",
        "label_zh": "拟人化",
        "beat_min": 3,
        "beat_max": 5,
        "effect": "物品轻声对话，只为把睡眠环境安顿好",
        "guidance": (
            "拟人化：以日常物品或自然物为主角，它们用极轻的声音对话。"
            "睡前限制：对话充满爱意；它们的行动都是为了让孩子或小动物睡得更舒服。"
        ),
        "sort_order": 50,
    },
]

_runtime: dict[str, dict[str, Any]] = {}
_runtime_ids: list[str] = []


def row_to_entry(row: StoryShape) -> dict[str, Any]:
    return {
        "id": row.id,
        "label": row.label_zh or row.id,
        "label_zh": row.label_zh or row.id,
        "guidance": row.guidance or "",
        "instruction": row.guidance or "",
        "effect": getattr(row, "effect", None) or "",
        "beat_min": int(row.beat_min or 2),
        "beat_max": int(row.beat_max or 6),
        "beat_hint": [],
        "enabled": bool(row.enabled),
        "sort_order": int(row.sort_order or 0),
        "story_shape": row.id,
    }


def apply_catalog(entries: list[dict[str, Any]]) -> None:
    global _runtime, _runtime_ids
    enabled = [e for e in entries if e.get("enabled", True)]
    enabled.sort(key=lambda e: (e.get("sort_order", 0), e.get("id") or ""))
    runtime: dict[str, dict[str, Any]] = {}
    for e in enabled:
        sid = e["id"]
        runtime[sid] = dict(e)
        runtime[sid]["story_shape"] = sid
    _runtime = runtime
    _runtime_ids = [e["id"] for e in enabled]
    logger.info("story_shapes catalog loaded count=%s", len(_runtime))


def apply_seed_fallback() -> None:
    apply_catalog(
        [
            {
                **s,
                "label": s["label_zh"],
                "instruction": s["guidance"],
                "effect": s.get("effect") or "",
                "beat_hint": [],
                "enabled": True,
                "story_shape": s["id"],
            }
            for s in SHAPE_SEED
        ]
    )


def get_runtime_shapes() -> dict[str, dict[str, Any]]:
    if not _runtime:
        apply_seed_fallback()
    return _runtime


def get_runtime_shape_ids() -> list[str]:
    if not _runtime:
        apply_seed_fallback()
    return list(_runtime_ids)


def default_shape_id() -> str:
    ids = get_runtime_shape_ids()
    if ids:
        return ids[0]
    return SHAPE_SEED[0]["id"]


def shape_payload(shape_id: str) -> dict[str, Any]:
    shapes = get_runtime_shapes()
    fallback = default_shape_id()
    sid = shape_id if shape_id in shapes else fallback
    if sid not in shapes:
        apply_seed_fallback()
        shapes = get_runtime_shapes()
        sid = shape_id if shape_id in shapes else default_shape_id()
    e = shapes[sid]
    instruction = e.get("guidance") or e.get("instruction") or ""
    return {
        "id": sid,
        "story_shape": sid,
        "label": e.get("label") or e.get("label_zh") or sid,
        "instruction": instruction,
        "effect": e.get("effect") or "",
        "beat_min": int(e.get("beat_min") or 2),
        "beat_max": int(e.get("beat_max") or 6),
        "beat_hint": [],
        "beat_roles": [],
        "lineage": "shape_pool",
    }


def shape_beat_range(shape_id: str) -> tuple[int, int]:
    p = shape_payload(shape_id)
    return int(p["beat_min"]), int(p["beat_max"])


def shape_guidance(shape_id: str) -> str:
    return str(shape_payload(shape_id).get("instruction") or "")


def default_roles_for_shape(shape_id: str) -> list[str]:
    return list(shape_payload(shape_id).get("beat_hint") or [])


def select_story_shape(
    focus_id: str | None = None,
    *,
    theme: str | None = None,
    episode_no: int = 1,
    salt: str = "",
    recent_shapes: list[str] | None = None,
) -> dict[str, Any]:
    """Pick an enabled story_shape; avoid recent shapes. No focus/theme bias."""
    shapes = get_runtime_shapes()
    all_ids = get_runtime_shape_ids() or list(shapes.keys())
    blocked = {str(s).strip() for s in (recent_shapes or [])[:2] if str(s).strip()}
    options = [s for s in all_ids if s not in blocked] or list(all_ids)
    digest = hashlib.sha256(
        f"shape|{focus_id or ''}|{theme or ''}|{episode_no}|{salt}|{','.join(options)}".encode()
    ).hexdigest()
    idx = int(digest[:8], 16) % len(options)
    return shape_payload(options[idx])


# Compat alias used by pipeline / tests
select_beat_pattern = select_story_shape


async def refresh_shape_catalog(db: AsyncSession) -> int:
    rows = (
        await db.execute(select(StoryShape).order_by(StoryShape.sort_order, StoryShape.id))
    ).scalars().all()
    if not rows:
        apply_seed_fallback()
        return 0
    apply_catalog([row_to_entry(r) for r in rows])
    return len(rows)


def _apply_seed(row: StoryShape, seed: dict[str, Any]) -> None:
    row.label_zh = seed["label_zh"]
    row.guidance = seed["guidance"]
    row.effect = seed.get("effect") or ""
    row.beat_min = seed["beat_min"]
    row.beat_max = seed["beat_max"]
    row.example_beats_json = "[]"
    row.enabled = True
    row.sort_order = seed["sort_order"]


async def seed_story_shapes_if_empty(db: AsyncSession) -> int:
    """Upsert classic shapes and drop the legacy bedtime-menu rows."""
    changed = 0
    for sid in LEGACY_SHAPE_IDS:
        row = await db.get(StoryShape, sid)
        if row is not None:
            await db.delete(row)
            changed += 1
    for seed in SHAPE_SEED:
        row = await db.get(StoryShape, seed["id"])
        if row is None:
            row = StoryShape(id=seed["id"])
            db.add(row)
        _apply_seed(row, seed)
        changed += 1
    await db.commit()
    await refresh_shape_catalog(db)
    logger.info("story_shapes reconciled changed=%s", changed)
    return changed
