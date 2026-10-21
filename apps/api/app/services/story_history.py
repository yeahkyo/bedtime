"""Recent episode history for story_shape soft-dedup and plan inject."""

from __future__ import annotations

import json
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.story import Story
from app.providers.story_prompt import empty_recent_history


def _parse_plan(raw: str | None) -> dict[str, Any]:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def _parse_params(raw: str | None) -> dict[str, Any]:
    return _parse_plan(raw)


async def load_recent_story_history(
    db: AsyncSession,
    *,
    child_id: int,
    exclude_story_id: int | None = None,
    limit: int = 5,
) -> dict[str, Any]:
    """Newest-first history for shapes (3), themes (5), core elements (3)."""
    q = (
        select(Story)
        .where(Story.child_id == child_id)
        .order_by(Story.id.desc())
        .limit(max(5, limit))
    )
    if exclude_story_id is not None:
        q = q.where(Story.id != exclude_story_id)
    rows = (await db.execute(q)).scalars().all()
    out = empty_recent_history()
    shapes: list[str] = []
    themes: list[Any] = []
    cores: list[str] = []
    last_summary = None
    for story in rows:
        plan = _parse_plan(story.episode_plan_json)
        params = _parse_params(story.params_json)
        shape = str(
            plan.get("shape")
            or plan.get("story_shape")
            or params.get("story_shape")
            or ""
        ).strip()
        if shape and shape not in shapes:
            shapes.append(shape)
        theme = plan.get("theme")
        if theme is None and "theme" in params:
            theme = params.get("theme")
        if theme is not None:
            t = str(theme).strip() or None
        else:
            t = None
        # Keep nulls in themes_used for dedupe semantics.
        if len(themes) < 5:
            themes.append(t)
        core = (
            plan.get("props")
            or plan.get("core_element")
            or params.get("core_element")
            or []
        )
        if isinstance(core, str):
            core = [core]
        for c in core:
            cs = str(c).strip()
            if cs and cs not in cores:
                cores.append(cs)
        if last_summary is None:
            last_summary = (
                plan.get("last_summary")
                or params.get("last_summary")
                or (str(story.title or "").strip() or None)
            )
            beats = plan.get("beats") or []
            if isinstance(beats, list) and beats and isinstance(beats[-1], dict):
                act = str(beats[-1].get("action") or "").strip()
                if act:
                    last_summary = act[:80]
    out["shapes_used"] = shapes[:3]
    out["themes_used"] = themes[:5]
    out["core_elements_used"] = cores[:3]
    out["last_summary"] = last_summary
    return out
