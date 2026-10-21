"""Admin CRUD for story_shapes (architecture pool)."""

from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.story_shape import StoryShape
from app.services.story_shapes import (
    refresh_shape_catalog,
    row_to_entry,
    seed_story_shapes_if_empty,
)

router = APIRouter(prefix="/shapes", tags=["admin-shapes"])

_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,62}$")


class ShapeOut(BaseModel):
    id: str
    label_zh: str
    guidance: str
    effect: str
    beat_min: int
    beat_max: int
    enabled: bool
    sort_order: int


class ShapeListOut(BaseModel):
    items: list[ShapeOut]
    total: int


class ShapeCreate(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    label_zh: str = Field(min_length=1, max_length=128)
    guidance: str = Field(min_length=1)
    effect: str = ""
    beat_min: int = Field(default=2, ge=1, le=12)
    beat_max: int = Field(default=6, ge=1, le=12)
    enabled: bool = True
    sort_order: int = 0


class ShapePatch(BaseModel):
    label_zh: str | None = Field(default=None, max_length=128)
    guidance: str | None = None
    effect: str | None = None
    beat_min: int | None = Field(default=None, ge=1, le=12)
    beat_max: int | None = Field(default=None, ge=1, le=12)
    enabled: bool | None = None
    sort_order: int | None = None


def _check_range(bmin: int, bmax: int) -> None:
    if bmin > bmax:
        raise HTTPException(status_code=400, detail="beat_min must be <= beat_max")


def _out(row: StoryShape) -> ShapeOut:
    e = row_to_entry(row)
    return ShapeOut(
        id=e["id"],
        label_zh=str(e.get("label_zh") or e.get("label") or e["id"]),
        guidance=str(e.get("guidance") or ""),
        effect=str(e.get("effect") or ""),
        beat_min=int(e.get("beat_min") or 2),
        beat_max=int(e.get("beat_max") or 6),
        enabled=bool(e.get("enabled", True)),
        sort_order=int(e.get("sort_order") or 0),
    )


@router.get("", response_model=ShapeListOut)
async def list_shapes(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ShapeListOut:
    await seed_story_shapes_if_empty(db)
    rows = (
        await db.execute(select(StoryShape).order_by(StoryShape.sort_order, StoryShape.id))
    ).scalars().all()
    return ShapeListOut(items=[_out(r) for r in rows], total=len(rows))


@router.get("/{shape_id}", response_model=ShapeOut)
async def get_shape(
    shape_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ShapeOut:
    row = await db.get(StoryShape, shape_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Shape not found")
    return _out(row)


@router.post("", response_model=ShapeOut, status_code=201)
async def create_shape(
    body: ShapeCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ShapeOut:
    sid = body.id.strip().lower()
    if not _ID_RE.match(sid):
        raise HTTPException(
            status_code=400,
            detail="id must be snake_case letters/digits/underscore",
        )
    if await db.get(StoryShape, sid) is not None:
        raise HTTPException(status_code=409, detail="Shape id already exists")
    _check_range(body.beat_min, body.beat_max)
    row = StoryShape(
        id=sid,
        label_zh=body.label_zh.strip(),
        guidance=body.guidance.strip(),
        effect=(body.effect or "").strip(),
        beat_min=body.beat_min,
        beat_max=body.beat_max,
        example_beats_json="[]",
        enabled=body.enabled,
        sort_order=body.sort_order,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    await refresh_shape_catalog(db)
    return _out(row)


@router.patch("/{shape_id}", response_model=ShapeOut)
async def patch_shape(
    shape_id: str,
    body: ShapePatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ShapeOut:
    row = await db.get(StoryShape, shape_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Shape not found")
    data = body.model_dump(exclude_unset=True)
    if "label_zh" in data and data["label_zh"] is not None:
        row.label_zh = data["label_zh"].strip()
    if "guidance" in data and data["guidance"] is not None:
        row.guidance = data["guidance"].strip()
    if "effect" in data and data["effect"] is not None:
        row.effect = data["effect"].strip()
    if "beat_min" in data and data["beat_min"] is not None:
        row.beat_min = int(data["beat_min"])
    if "beat_max" in data and data["beat_max"] is not None:
        row.beat_max = int(data["beat_max"])
    _check_range(int(row.beat_min), int(row.beat_max))
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    if "sort_order" in data and data["sort_order"] is not None:
        row.sort_order = int(data["sort_order"])
    await db.commit()
    await db.refresh(row)
    await refresh_shape_catalog(db)
    return _out(row)


@router.delete("/{shape_id}", status_code=204, response_class=Response)
async def delete_shape(
    shape_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(StoryShape, shape_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Shape not found")
    await db.delete(row)
    await db.commit()
    await refresh_shape_catalog(db)
    return Response(status_code=204)
