"""Load / seed / cache story beat patterns for plan selection + admin CRUD."""

from __future__ import annotations

import json
import logging
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.beat_pattern import StoryBeatPattern
from app.providers.story_prompt import (
    BEAT_PATTERNS,
    DEFAULT_BEAT_POOL,
    FOCUS_BEAT_MAP,
    _BEAT_SLOTS,
    _ESCALATION_RULE,
)

logger = logging.getLogger(__name__)

# In-memory catalog used by sync select_beat_pattern (refreshed on seed / admin write).
_runtime_patterns: dict[str, dict[str, Any]] = {}
_runtime_focus_map: dict[str, list[str]] = {}
_runtime_default_pool: list[str] = list(DEFAULT_BEAT_POOL)


def _invert_focus_map() -> dict[str, list[str]]:
    inverted: dict[str, list[str]] = {pid: [] for pid in BEAT_PATTERNS}
    for focus_id, pids in FOCUS_BEAT_MAP.items():
        for pid in pids:
            inverted.setdefault(pid, []).append(focus_id)
    return inverted


def seed_rows_from_constants() -> list[dict[str, Any]]:
    """Build seed dicts from code constants (idempotent insert source)."""
    focus_by_beat = _invert_focus_map()
    rows: list[dict[str, Any]] = []
    for i, (pid, meta) in enumerate(BEAT_PATTERNS.items()):
        rows.append(
            {
                "id": pid,
                "label": meta.get("label") or pid,
                "lineage": meta.get("lineage") or "",
                "theme_tags": list(meta.get("theme_tags") or ()),
                "slots": meta.get("slots") or _BEAT_SLOTS,
                "instruction": meta.get("instruction") or "",
                "escalation": _ESCALATION_RULE,
                "focus_ids": focus_by_beat.get(pid) or [],
                "enabled": True,
                "sort_order": i * 10,
            }
        )
    return rows


def _parse_json_list(raw: str | None) -> list[str]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    return [str(x).strip() for x in data if str(x).strip()]


def row_to_catalog_entry(row: StoryBeatPattern) -> dict[str, Any]:
    return {
        "id": row.id,
        "label": row.label,
        "lineage": row.lineage or "",
        "theme_tags": tuple(_parse_json_list(row.theme_tags_json)),
        "slots": row.slots or _BEAT_SLOTS,
        "instruction": row.instruction or "",
        "escalation": (row.escalation or _ESCALATION_RULE).strip(),
        "focus_ids": _parse_json_list(row.focus_ids_json),
        "enabled": bool(row.enabled),
        "sort_order": int(row.sort_order or 0),
    }


def apply_catalog(entries: list[dict[str, Any]]) -> None:
    """Replace in-memory catalog (enabled patterns only for selection)."""
    global _runtime_patterns, _runtime_focus_map, _runtime_default_pool
    enabled = [e for e in entries if e.get("enabled", True)]
    enabled.sort(key=lambda e: (e.get("sort_order", 0), e.get("id") or ""))
    patterns: dict[str, dict[str, Any]] = {}
    focus_map: dict[str, list[str]] = {}
    for e in enabled:
        pid = e["id"]
        patterns[pid] = {
            "label": e["label"],
            "lineage": e.get("lineage") or "",
            "theme_tags": tuple(e.get("theme_tags") or ()),
            "slots": e.get("slots") or _BEAT_SLOTS,
            "instruction": e.get("instruction") or "",
            "escalation": e.get("escalation") or _ESCALATION_RULE,
        }
        for fid in e.get("focus_ids") or []:
            focus_map.setdefault(fid, []).append(pid)
    _runtime_patterns = patterns
    _runtime_focus_map = focus_map
    _runtime_default_pool = [e["id"] for e in enabled] or list(DEFAULT_BEAT_POOL)
    logger.info(
        "beat_catalog loaded patterns=%s focus_keys=%s",
        len(_runtime_patterns),
        len(_runtime_focus_map),
    )


def apply_seed_catalog_fallback() -> None:
    """Use code constants when DB is empty / unavailable."""
    apply_catalog(seed_rows_from_constants())


def get_runtime_patterns() -> dict[str, dict[str, Any]]:
    if not _runtime_patterns:
        apply_seed_catalog_fallback()
    return _runtime_patterns


def get_runtime_focus_map() -> dict[str, list[str]]:
    if not _runtime_patterns:
        apply_seed_catalog_fallback()
    return _runtime_focus_map


def get_runtime_default_pool() -> list[str]:
    if not _runtime_patterns:
        apply_seed_catalog_fallback()
    return list(_runtime_default_pool)


async def refresh_beat_catalog(db: AsyncSession) -> int:
    rows = (
        await db.execute(select(StoryBeatPattern).order_by(StoryBeatPattern.sort_order, StoryBeatPattern.id))
    ).scalars().all()
    if not rows:
        apply_seed_catalog_fallback()
        return 0
    apply_catalog([row_to_catalog_entry(r) for r in rows])
    return len(rows)


BEAT_SEED_DONE_KEY = "bedtime:beat_patterns_seed_done"


async def _beat_seed_done() -> bool:
    try:
        from app.core.redis_client import get_redis

        redis = await get_redis()
        return bool(await redis.get(BEAT_SEED_DONE_KEY))
    except Exception:
        return False


async def mark_beat_seed_done() -> None:
    """Remember that the catalog was initialized (or intentionally emptied)."""
    try:
        from app.core.redis_client import get_redis

        redis = await get_redis()
        await redis.set(BEAT_SEED_DONE_KEY, "1")
    except Exception:
        logger.warning("beat_patterns seed flag not persisted (redis unavailable)")


async def seed_beat_patterns_if_empty(db: AsyncSession) -> int:
    """Insert seed rows only on first empty catalog.

    After admin deletes every row, the seed-done flag prevents silently
    restoring the default catalog on the next list/startup.
    """
    count = int(
        (await db.execute(select(func.count()).select_from(StoryBeatPattern))).scalar_one()
    )
    if count > 0:
        await refresh_beat_catalog(db)
        await mark_beat_seed_done()
        return 0
    if await _beat_seed_done():
        apply_seed_catalog_fallback()
        logger.info("beat_patterns table empty but seed already done; skip re-insert")
        return 0
    inserted = 0
    for seed in seed_rows_from_constants():
        db.add(
            StoryBeatPattern(
                id=seed["id"],
                label=seed["label"],
                lineage=seed["lineage"],
                theme_tags_json=json.dumps(seed["theme_tags"], ensure_ascii=False),
                slots=seed["slots"],
                instruction=seed["instruction"],
                escalation=seed["escalation"],
                focus_ids_json=json.dumps(seed["focus_ids"], ensure_ascii=False),
                enabled=True,
                sort_order=seed["sort_order"],
            )
        )
        inserted += 1
    await db.commit()
    await refresh_beat_catalog(db)
    await mark_beat_seed_done()
    logger.info("beat_patterns seeded count=%s", inserted)
    return inserted
