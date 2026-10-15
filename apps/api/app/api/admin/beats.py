"""Admin CRUD for story beat / rhythm frames."""

from __future__ import annotations

import json
import re

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.beat_pattern import StoryBeatPattern
from app.providers.story_prompt import _BEAT_SLOTS, _ESCALATION_RULE
from app.services.beat_patterns import (
    mark_beat_seed_done,
    refresh_beat_catalog,
    row_to_catalog_entry,
    seed_beat_patterns_if_empty,
)

router = APIRouter(prefix="/beats", tags=["admin-beats"])

_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,62}$")


class BeatPatternOut(BaseModel):
    id: str
    label: str
    lineage: str
    theme_tags: list[str]
    slots: str
    instruction: str
    escalation: str | None
    focus_ids: list[str]
    enabled: bool
    sort_order: int


class BeatPatternListOut(BaseModel):
    items: list[BeatPatternOut]
    total: int


class BeatPatternCreate(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    label: str = Field(min_length=1, max_length=128)
    lineage: str = Field(default="", max_length=32)
    theme_tags: list[str] = Field(default_factory=list)
    slots: str = Field(default=_BEAT_SLOTS, max_length=256)
    instruction: str = Field(min_length=1)
    escalation: str | None = None
    focus_ids: list[str] = Field(default_factory=list)
    enabled: bool = True
    sort_order: int = 0


class BeatPatternPatch(BaseModel):
    label: str | None = Field(default=None, max_length=128)
    lineage: str | None = Field(default=None, max_length=32)
    theme_tags: list[str] | None = None
    slots: str | None = Field(default=None, max_length=256)
    instruction: str | None = None
    escalation: str | None = None
    focus_ids: list[str] | None = None
    enabled: bool | None = None
    sort_order: int | None = None


def _out(row: StoryBeatPattern) -> BeatPatternOut:
    e = row_to_catalog_entry(row)
    return BeatPatternOut(
        id=e["id"],
        label=e["label"],
        lineage=e["lineage"],
        theme_tags=list(e["theme_tags"]),
        slots=e["slots"],
        instruction=e["instruction"],
        escalation=e.get("escalation"),
        focus_ids=list(e.get("focus_ids") or []),
        enabled=bool(e.get("enabled", True)),
        sort_order=int(e.get("sort_order") or 0),
    )


@router.get("", response_model=BeatPatternListOut)
async def list_beats(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> BeatPatternListOut:
    await seed_beat_patterns_if_empty(db)
    rows = (
        await db.execute(
            select(StoryBeatPattern).order_by(StoryBeatPattern.sort_order, StoryBeatPattern.id)
        )
    ).scalars().all()
    return BeatPatternListOut(items=[_out(r) for r in rows], total=len(rows))


@router.get("/{beat_id}", response_model=BeatPatternOut)
async def get_beat(
    beat_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> BeatPatternOut:
    row = await db.get(StoryBeatPattern, beat_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Beat pattern not found")
    return _out(row)


@router.post("", response_model=BeatPatternOut, status_code=201)
async def create_beat(
    body: BeatPatternCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> BeatPatternOut:
    pid = body.id.strip().lower()
    if not _ID_RE.match(pid):
        raise HTTPException(
            status_code=400,
            detail="id must be snake_case letters/digits/underscore",
        )
    existing = await db.get(StoryBeatPattern, pid)
    if existing is not None:
        raise HTTPException(status_code=409, detail="Beat id already exists")
    row = StoryBeatPattern(
        id=pid,
        label=body.label.strip(),
        lineage=(body.lineage or "").strip(),
        theme_tags_json=json.dumps(body.theme_tags, ensure_ascii=False),
        slots=(body.slots or _BEAT_SLOTS).strip(),
        instruction=body.instruction.strip(),
        escalation=(body.escalation or _ESCALATION_RULE).strip(),
        focus_ids_json=json.dumps(body.focus_ids, ensure_ascii=False),
        enabled=body.enabled,
        sort_order=body.sort_order,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    await refresh_beat_catalog(db)
    return _out(row)


@router.patch("/{beat_id}", response_model=BeatPatternOut)
async def patch_beat(
    beat_id: str,
    body: BeatPatternPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> BeatPatternOut:
    row = await db.get(StoryBeatPattern, beat_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Beat pattern not found")
    data = body.model_dump(exclude_unset=True)
    if "label" in data and data["label"] is not None:
        row.label = data["label"].strip()
    if "lineage" in data and data["lineage"] is not None:
        row.lineage = data["lineage"].strip()
    if "theme_tags" in data and data["theme_tags"] is not None:
        row.theme_tags_json = json.dumps(data["theme_tags"], ensure_ascii=False)
    if "slots" in data and data["slots"] is not None:
        row.slots = data["slots"].strip() or _BEAT_SLOTS
    if "instruction" in data and data["instruction"] is not None:
        row.instruction = data["instruction"].strip()
    if "escalation" in data:
        row.escalation = (data["escalation"] or "").strip() or None
    if "focus_ids" in data and data["focus_ids"] is not None:
        row.focus_ids_json = json.dumps(data["focus_ids"], ensure_ascii=False)
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    if "sort_order" in data and data["sort_order"] is not None:
        row.sort_order = int(data["sort_order"])
    await db.commit()
    await db.refresh(row)
    await refresh_beat_catalog(db)
    return _out(row)


@router.delete("/{beat_id}", status_code=204, response_class=Response)
async def delete_beat(
    beat_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(StoryBeatPattern, beat_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Beat pattern not found")
    await db.delete(row)
    await db.commit()
    await refresh_beat_catalog(db)
    # Keep seed-done flag so an empty table is not auto-refilled on next list.
    await mark_beat_seed_done()
    return Response(status_code=204)
