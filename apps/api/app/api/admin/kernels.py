"""Admin CRUD for story kernel catalog."""

from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.story_kernel import StoryKernel
from app.services.element_age_stages import AGE_STAGE_IDS, AGE_STAGES
from app.services.element_generation import ELEMENT_GEN_PROVIDERS
from app.services.kernel_generation import (
    AXIS_IDS,
    generate_defaults,
    run_kernel_generation,
)
from app.services.story_kernels import (
    AXIS_LABELS_ZH,
    upsert_canonical_kernels,
)

router = APIRouter(tags=["admin-kernels"])

_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,62}$")


class KernelOut(BaseModel):
    id: str
    axis: str
    axis_label: str | None = None
    name: str
    soft_guidance: str
    age_stage: str
    age_stage_label_zh: str | None = None
    focus_id: str
    enabled: bool
    sort_order: int


class KernelListOut(BaseModel):
    items: list[KernelOut]
    total: int


class KernelCreate(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    axis: str = Field(min_length=1, max_length=32)
    name: str = Field(min_length=1, max_length=128)
    soft_guidance: str = Field(min_length=1)
    age_stage: str = Field(default="preschool_3_5", max_length=32)
    focus_id: str = Field(min_length=1, max_length=64)
    enabled: bool = True
    sort_order: int = 0


class KernelPatch(BaseModel):
    axis: str | None = Field(default=None, max_length=32)
    name: str | None = Field(default=None, max_length=128)
    soft_guidance: str | None = None
    age_stage: str | None = Field(default=None, max_length=32)
    focus_id: str | None = Field(default=None, max_length=64)
    enabled: bool | None = None
    sort_order: int | None = None


class GenerateDefaultsOut(BaseModel):
    providers: list[str]
    defaults: dict[str, str]
    age_stages: list[dict] = Field(default_factory=list)
    axes: list[dict] = Field(default_factory=list)
    focus_ids: list[str] = Field(default_factory=list)


class KernelGenerateBody(BaseModel):
    age_stage: str = Field(min_length=2, max_length=32)
    axis: str = Field(min_length=2, max_length=32)
    provider: str = Field(min_length=2, max_length=32)
    model: str = Field(min_length=1, max_length=128)
    count: int = Field(default=10, ge=1, le=30)


class KernelGenerateOut(BaseModel):
    created: int
    updated: int
    total: int
    provider: str
    model: str
    age_stage: str
    axis: str
    axis_label: str | None = None
    items_preview: list[dict]


def _check_id(raw: str) -> str:
    pid = raw.strip().lower()
    if not _ID_RE.match(pid):
        raise HTTPException(
            status_code=400,
            detail="id must be snake_case letters/digits/underscore",
        )
    return pid


def _validate_stage(age_stage: str) -> str:
    sid = (age_stage or "").strip()
    if sid not in AGE_STAGES:
        raise HTTPException(
            status_code=400,
            detail=f"age_stage must be one of {', '.join(AGE_STAGE_IDS)}",
        )
    return sid


def _out(row: StoryKernel) -> KernelOut:
    stage = AGE_STAGES.get(row.age_stage) or {}
    return KernelOut(
        id=row.id,
        axis=row.axis,
        axis_label=AXIS_LABELS_ZH.get(row.axis),
        name=row.name,
        soft_guidance=row.soft_guidance or "",
        age_stage=row.age_stage,
        age_stage_label_zh=stage.get("label_zh"),
        focus_id=row.focus_id,
        enabled=bool(row.enabled),
        sort_order=int(row.sort_order or 0),
    )


@router.post("/kernels/seed")
async def seed_kernels(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> dict:
    n = await upsert_canonical_kernels(db)
    return {"upserted": n}


@router.get("/kernels/generate-defaults", response_model=GenerateDefaultsOut)
async def get_kernel_generate_defaults(
    _: str = Depends(require_admin),
) -> GenerateDefaultsOut:
    data = generate_defaults()
    return GenerateDefaultsOut(
        providers=data["providers"],
        defaults=data["defaults"],
        age_stages=data.get("age_stages") or [],
        axes=data.get("axes") or [],
        focus_ids=data.get("focus_ids") or [],
    )


@router.post("/kernels/generate", response_model=KernelGenerateOut)
async def generate_kernels(
    body: KernelGenerateBody,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> KernelGenerateOut:
    provider = body.provider.strip().lower()
    if provider not in ELEMENT_GEN_PROVIDERS:
        raise HTTPException(
            status_code=400,
            detail=f"provider must be one of {', '.join(ELEMENT_GEN_PROVIDERS)}",
        )
    age_stage = _validate_stage(body.age_stage)
    axis = body.axis.strip().lower()
    if axis not in AXIS_IDS:
        raise HTTPException(
            status_code=400,
            detail=f"axis must be one of {', '.join(AXIS_IDS)}",
        )
    try:
        result = await run_kernel_generation(
            db,
            age_stage=age_stage,
            axis=axis,
            provider=provider,
            model=body.model.strip(),
            count=body.count,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return KernelGenerateOut(**result)


@router.get("/kernels", response_model=KernelListOut)
async def list_kernels(
    axis: str | None = Query(default=None),
    age_stage: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    q: str | None = Query(default=None, max_length=128),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> KernelListOut:
    filters = []
    if axis:
        filters.append(StoryKernel.axis == axis.strip())
    if age_stage:
        filters.append(StoryKernel.age_stage == _validate_stage(age_stage))
    if enabled is not None:
        filters.append(StoryKernel.enabled.is_(enabled))
    if q and q.strip():
        like = f"%{q.strip()}%"
        filters.append(
            or_(
                StoryKernel.name.ilike(like),
                StoryKernel.id.ilike(like),
                StoryKernel.focus_id.ilike(like),
                StoryKernel.soft_guidance.ilike(like),
            )
        )
    count_q = select(func.count()).select_from(StoryKernel)
    list_q = (
        select(StoryKernel)
        .order_by(StoryKernel.sort_order, StoryKernel.id)
        .offset(offset)
        .limit(limit)
    )
    if filters:
        count_q = count_q.where(*filters)
        list_q = list_q.where(*filters)
    total = int((await db.execute(count_q)).scalar_one())
    rows = (await db.execute(list_q)).scalars().all()
    return KernelListOut(items=[_out(r) for r in rows], total=total)


@router.get("/kernels/{kernel_id}", response_model=KernelOut)
async def get_kernel(
    kernel_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> KernelOut:
    row = await db.get(StoryKernel, kernel_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Kernel not found")
    return _out(row)


@router.post("/kernels", response_model=KernelOut, status_code=201)
async def create_kernel(
    body: KernelCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> KernelOut:
    pid = _check_id(body.id)
    stage = _validate_stage(body.age_stage)
    if await db.get(StoryKernel, pid) is not None:
        raise HTTPException(status_code=409, detail="Kernel id already exists")
    row = StoryKernel(
        id=pid,
        axis=body.axis.strip(),
        name=body.name.strip(),
        soft_guidance=body.soft_guidance.strip(),
        age_stage=stage,
        focus_id=body.focus_id.strip(),
        enabled=body.enabled,
        sort_order=body.sort_order,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return _out(row)


@router.patch("/kernels/{kernel_id}", response_model=KernelOut)
async def patch_kernel(
    kernel_id: str,
    body: KernelPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> KernelOut:
    row = await db.get(StoryKernel, kernel_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Kernel not found")
    data = body.model_dump(exclude_unset=True)
    if "axis" in data and data["axis"] is not None:
        row.axis = data["axis"].strip()
    if "name" in data and data["name"] is not None:
        row.name = data["name"].strip()
    if "soft_guidance" in data and data["soft_guidance"] is not None:
        row.soft_guidance = data["soft_guidance"].strip()
    if "age_stage" in data and data["age_stage"] is not None:
        row.age_stage = _validate_stage(data["age_stage"])
    if "focus_id" in data and data["focus_id"] is not None:
        row.focus_id = data["focus_id"].strip()
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    if "sort_order" in data and data["sort_order"] is not None:
        row.sort_order = int(data["sort_order"])
    await db.commit()
    await db.refresh(row)
    return _out(row)


@router.delete("/kernels/{kernel_id}", status_code=204, response_class=Response)
async def delete_kernel(
    kernel_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(StoryKernel, kernel_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Kernel not found")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)
