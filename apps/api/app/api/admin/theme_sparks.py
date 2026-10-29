"""Admin CRUD for theme spark catalog (create-page inspiration hint examples)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.theme_spark import ThemeSpark
from app.services.theme_sparks import (
    normalize_spark_language,
    seed_theme_sparks_if_empty,
)

router = APIRouter(prefix="/theme-sparks", tags=["admin-theme-sparks"])


class ThemeSparkOut(BaseModel):
    id: int
    language: str
    text: str
    enabled: bool
    sort_order: int


class ThemeSparkListOut(BaseModel):
    items: list[ThemeSparkOut]
    total: int


class ThemeSparkCreate(BaseModel):
    language: str = Field(default="zh", max_length=8)
    text: str = Field(min_length=1, max_length=64)
    enabled: bool = True
    sort_order: int = 0


class ThemeSparkPatch(BaseModel):
    language: str | None = Field(default=None, max_length=8)
    text: str | None = Field(default=None, min_length=1, max_length=64)
    enabled: bool | None = None
    sort_order: int | None = None


class SeedOut(BaseModel):
    inserted: int
    already_present: bool


def _out(row: ThemeSpark) -> ThemeSparkOut:
    return ThemeSparkOut(
        id=row.id,
        language=row.language,
        text=row.text,
        enabled=row.enabled,
        sort_order=row.sort_order,
    )


@router.get("", response_model=ThemeSparkListOut)
async def list_theme_sparks(
    language: str | None = Query(default=None, max_length=8),
    enabled: bool | None = Query(default=None),
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ThemeSparkListOut:
    await seed_theme_sparks_if_empty(db)
    q = select(ThemeSpark)
    if language:
        q = q.where(ThemeSpark.language == normalize_spark_language(language))
    if enabled is not None:
        q = q.where(ThemeSpark.enabled.is_(enabled))
    q = q.order_by(ThemeSpark.language, ThemeSpark.sort_order, ThemeSpark.id)
    rows = (await db.execute(q)).scalars().all()
    return ThemeSparkListOut(items=[_out(r) for r in rows], total=len(rows))


@router.post("", response_model=ThemeSparkOut, status_code=201)
async def create_theme_spark(
    body: ThemeSparkCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ThemeSparkOut:
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is required")
    row = ThemeSpark(
        language=normalize_spark_language(body.language),
        text=text,
        enabled=body.enabled,
        sort_order=body.sort_order,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return _out(row)


@router.patch("/{spark_id}", response_model=ThemeSparkOut)
async def patch_theme_spark(
    spark_id: int,
    body: ThemeSparkPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ThemeSparkOut:
    row = await db.get(ThemeSpark, spark_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Theme spark not found")
    if body.language is not None:
        row.language = normalize_spark_language(body.language)
    if body.text is not None:
        text = body.text.strip()
        if not text:
            raise HTTPException(status_code=400, detail="text is required")
        row.text = text
    if body.enabled is not None:
        row.enabled = body.enabled
    if body.sort_order is not None:
        row.sort_order = body.sort_order
    await db.commit()
    await db.refresh(row)
    return _out(row)


@router.delete("/{spark_id}", status_code=204, response_class=Response)
async def delete_theme_spark(
    spark_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(ThemeSpark, spark_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Theme spark not found")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)


@router.post("/seed", response_model=SeedOut)
async def seed_theme_sparks(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> SeedOut:
    """Insert code defaults only when empty (does not overwrite admin edits)."""
    before = int((await db.execute(select(func.count()).select_from(ThemeSpark))).scalar_one())
    if before > 0:
        return SeedOut(inserted=0, already_present=True)
    inserted = await seed_theme_sparks_if_empty(db)
    return SeedOut(inserted=inserted, already_present=False)
