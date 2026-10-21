"""Public read API for story-element suggestion chips."""

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.user import User
from app.services.story_elements import suggest_elements

router = APIRouter(prefix="/elements", tags=["elements"])


class ElementChipOut(BaseModel):
    id: str
    name: str
    subcategory: str
    age_stage: str


class ElementListOut(BaseModel):
    items: list[ElementChipOut]
    total: int
    age_band: str


@router.get("", response_model=ElementListOut)
async def list_element_suggestions(
    age_band: str = Query(default="3-5", max_length=16),
    limit: int = Query(default=12, ge=1, le=40),
    child_id: int | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ElementListOut:
    from app.providers.story_prompt import normalize_age_band

    band = normalize_age_band(age_band)
    if child_id is not None:
        child = await db.get(Child, child_id)
        if child is None or child.user_id != user.id:
            child_id = None
    items_raw = await suggest_elements(
        db, age_band=band, limit=limit, child_id=child_id
    )
    items = [ElementChipOut(**x) for x in items_raw]
    return ElementListOut(items=items, total=len(items), age_band=band)
