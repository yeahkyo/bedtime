"""Public read API for story kernel chips (by age band)."""

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.user import User
from app.services.story_kernels import suggest_kernels

router = APIRouter(prefix="/kernels", tags=["kernels"])


class KernelChipOut(BaseModel):
    id: str
    axis: str
    axis_label: str
    name: str
    focus_id: str
    age_stage: str


class KernelListOut(BaseModel):
    items: list[KernelChipOut]
    total: int
    age_band: str


@router.get("", response_model=KernelListOut)
async def list_kernels(
    age_band: str = Query(default="3-5", max_length=16),
    limit: int = Query(default=12, ge=1, le=40),
    child_id: int | None = Query(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> KernelListOut:
    from app.providers.story_prompt import normalize_age_band

    band = normalize_age_band(age_band)
    if child_id is not None:
        child = await db.get(Child, child_id)
        if child is None or child.user_id != user.id:
            child_id = None
    items_raw = await suggest_kernels(
        db, age_band=band, limit=limit, child_id=child_id
    )
    items = [KernelChipOut(**x) for x in items_raw]
    return KernelListOut(items=items, total=len(items), age_band=band)
