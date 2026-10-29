"""Public read API for create-page theme spark hints (sync to local pool)."""

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.services.theme_sparks import (
    list_enabled_sparks_for_user,
    normalize_spark_language,
    seed_theme_sparks_if_empty,
)

router = APIRouter(prefix="/theme-sparks", tags=["theme-sparks"])


class ThemeSparkOut(BaseModel):
    id: int
    text: str


class ThemeSparkListOut(BaseModel):
    items: list[ThemeSparkOut]
    language: str
    total: int


@router.get("", response_model=ThemeSparkListOut)
async def list_theme_sparks(
    language: str = Query(default="zh", max_length=16),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ThemeSparkListOut:
    await seed_theme_sparks_if_empty(db)
    lang = normalize_spark_language(language)
    rows = await list_enabled_sparks_for_user(
        db, language=lang, user_id=user.id
    )
    items = [ThemeSparkOut(id=r.id, text=r.text) for r in rows if (r.text or "").strip()]
    return ThemeSparkListOut(items=items, language=lang, total=len(items))
