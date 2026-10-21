"""Admin CRUD for story element taxonomy + knowledge catalog."""

from __future__ import annotations

import re

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.security import require_admin
from app.models.story_element import (
    StoryElement,
    StoryElementCategory,
    StoryElementSubcategory,
)
from app.services.element_age_stages import AGE_STAGE_IDS, AGE_STAGES, age_stage_for_years
from app.services.element_generation import (
    ELEMENT_GEN_PROVIDERS,
    generate_defaults,
    inventory_for_subcategory,
    run_element_generation,
)
from app.services.story_elements import upsert_canonical_taxonomy

router = APIRouter(tags=["admin-elements"])

_ID_RE = re.compile(r"^[a-z][a-z0-9_]{1,62}$")


# —— Schemas ——


class CategoryOut(BaseModel):
    id: str
    label_zh: str
    label_en: str
    sort_order: int
    enabled: bool


class CategoryListOut(BaseModel):
    items: list[CategoryOut]
    total: int


class CategoryCreate(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    label_zh: str = Field(min_length=1, max_length=128)
    label_en: str = Field(default="", max_length=128)
    sort_order: int = 0
    enabled: bool = True


class CategoryPatch(BaseModel):
    label_zh: str | None = Field(default=None, max_length=128)
    label_en: str | None = Field(default=None, max_length=128)
    sort_order: int | None = None
    enabled: bool | None = None


class SubcategoryOut(BaseModel):
    id: str
    category_id: str
    label_zh: str
    label_en: str
    generation_brief: str | None = None
    id_prefix: str | None = None
    sort_order: int
    enabled: bool


class SubcategoryListOut(BaseModel):
    items: list[SubcategoryOut]
    total: int


class SubcategoryCreate(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    category_id: str = Field(min_length=2, max_length=64)
    label_zh: str = Field(min_length=1, max_length=128)
    label_en: str = Field(default="", max_length=128)
    generation_brief: str | None = None
    id_prefix: str | None = Field(default=None, max_length=16)
    sort_order: int = 0
    enabled: bool = True


class SubcategoryPatch(BaseModel):
    category_id: str | None = Field(default=None, max_length=64)
    label_zh: str | None = Field(default=None, max_length=128)
    label_en: str | None = Field(default=None, max_length=128)
    generation_brief: str | None = None
    id_prefix: str | None = Field(default=None, max_length=16)
    sort_order: int | None = None
    enabled: bool | None = None


class GenerateDefaultsOut(BaseModel):
    providers: list[str]
    defaults: dict[str, str]
    age_stages: list[dict] = Field(default_factory=list)
    subcategory_target_total: int = 100
    stage_targets: dict[str, int] = Field(default_factory=dict)


class ElementGenerateBody(BaseModel):
    subcategory_id: str = Field(min_length=2, max_length=64)
    age_stage: str = Field(min_length=2, max_length=32)
    provider: str = Field(min_length=2, max_length=32)
    model: str = Field(min_length=1, max_length=128)
    count: int = Field(default=50, ge=1, le=50)


class ElementGenerateOut(BaseModel):
    created: int
    updated: int
    total: int
    provider: str
    model: str
    age_stage: str
    items_preview: list[dict]
    inventory: dict | None = None


class InventoryOut(BaseModel):
    subcategory_id: str
    target_total: int
    targets: dict[str, int]
    counts: dict[str, int]
    gaps: dict[str, int]
    total: int


def _sub_out(r: StoryElementSubcategory) -> SubcategoryOut:
    return SubcategoryOut(
        id=r.id,
        category_id=r.category_id,
        label_zh=r.label_zh,
        label_en=r.label_en or "",
        generation_brief=r.generation_brief,
        id_prefix=r.id_prefix,
        sort_order=r.sort_order,
        enabled=bool(r.enabled),
    )


class ElementOut(BaseModel):
    id: str
    category_id: str
    subcategory_id: str
    name: str
    description: str
    age_stage: str
    age_stage_label_zh: str | None = None
    enabled: bool
    category_label_zh: str | None = None
    subcategory_label_zh: str | None = None


class ElementListOut(BaseModel):
    items: list[ElementOut]
    total: int


class ElementCreate(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    category_id: str = Field(min_length=2, max_length=64)
    subcategory_id: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=256)
    description: str = Field(min_length=1)
    age_stage: str = Field(default="preschool_3_5", max_length=32)
    enabled: bool = True


class ElementPatch(BaseModel):
    category_id: str | None = Field(default=None, max_length=64)
    subcategory_id: str | None = Field(default=None, max_length=64)
    name: str | None = Field(default=None, max_length=256)
    description: str | None = None
    age_stage: str | None = Field(default=None, max_length=32)
    enabled: bool | None = None


class ElementImportItem(BaseModel):
    id: str = Field(min_length=2, max_length=64)
    category_id: str
    subcategory_id: str
    name: str
    description: str
    age_stage: str = "preschool_3_5"
    enabled: bool = True


class ElementImportBody(BaseModel):
    items: list[ElementImportItem] = Field(min_length=1, max_length=500)


class ElementImportOut(BaseModel):
    created: int
    updated: int
    total: int


def _check_id(raw: str) -> str:
    pid = raw.strip().lower()
    if not _ID_RE.match(pid):
        raise HTTPException(
            status_code=400,
            detail="id must be snake_case letters/digits/underscore",
        )
    return pid


def _validate_age_stage(age_stage: str) -> str:
    sid = (age_stage or "").strip()
    if sid not in AGE_STAGES:
        raise HTTPException(
            status_code=400,
            detail=f"age_stage must be one of {', '.join(AGE_STAGE_IDS)}",
        )
    return sid


def _element_out(row: StoryElement) -> ElementOut:
    stage = AGE_STAGES.get(row.age_stage) or {}
    return ElementOut(
        id=row.id,
        category_id=row.category_id,
        subcategory_id=row.subcategory_id,
        name=row.name,
        description=row.description or "",
        age_stage=row.age_stage,
        age_stage_label_zh=stage.get("label_zh"),
        enabled=bool(row.enabled),
        category_label_zh=row.category.label_zh if row.category else None,
        subcategory_label_zh=row.subcategory.label_zh if row.subcategory else None,
    )


async def _validate_taxonomy(
    db: AsyncSession, category_id: str, subcategory_id: str
) -> StoryElementSubcategory:
    cat = await db.get(StoryElementCategory, category_id)
    if cat is None:
        raise HTTPException(status_code=400, detail="category_id not found")
    sub = await db.get(StoryElementSubcategory, subcategory_id)
    if sub is None:
        raise HTTPException(status_code=400, detail="subcategory_id not found")
    if sub.category_id != category_id:
        raise HTTPException(
            status_code=400,
            detail="subcategory_id does not belong to category_id",
        )
    return sub


# —— Categories ——


@router.get("/element-categories", response_model=CategoryListOut)
async def list_categories(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> CategoryListOut:
    await upsert_canonical_taxonomy(db)
    rows = (
        await db.execute(
            select(StoryElementCategory).order_by(
                StoryElementCategory.sort_order, StoryElementCategory.id
            )
        )
    ).scalars().all()
    items = [
        CategoryOut(
            id=r.id,
            label_zh=r.label_zh,
            label_en=r.label_en or "",
            sort_order=r.sort_order,
            enabled=bool(r.enabled),
        )
        for r in rows
    ]
    return CategoryListOut(items=items, total=len(items))


@router.post("/element-categories", response_model=CategoryOut, status_code=201)
async def create_category(
    body: CategoryCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> CategoryOut:
    pid = _check_id(body.id)
    if await db.get(StoryElementCategory, pid) is not None:
        raise HTTPException(status_code=409, detail="Category id already exists")
    row = StoryElementCategory(
        id=pid,
        label_zh=body.label_zh.strip(),
        label_en=(body.label_en or "").strip(),
        sort_order=body.sort_order,
        enabled=body.enabled,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return CategoryOut(
        id=row.id,
        label_zh=row.label_zh,
        label_en=row.label_en or "",
        sort_order=row.sort_order,
        enabled=bool(row.enabled),
    )


@router.patch("/element-categories/{category_id}", response_model=CategoryOut)
async def patch_category(
    category_id: str,
    body: CategoryPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> CategoryOut:
    row = await db.get(StoryElementCategory, category_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Category not found")
    data = body.model_dump(exclude_unset=True)
    if "label_zh" in data and data["label_zh"] is not None:
        row.label_zh = data["label_zh"].strip()
    if "label_en" in data and data["label_en"] is not None:
        row.label_en = data["label_en"].strip()
    if "sort_order" in data and data["sort_order"] is not None:
        row.sort_order = int(data["sort_order"])
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    await db.commit()
    await db.refresh(row)
    return CategoryOut(
        id=row.id,
        label_zh=row.label_zh,
        label_en=row.label_en or "",
        sort_order=row.sort_order,
        enabled=bool(row.enabled),
    )


@router.delete("/element-categories/{category_id}", status_code=204, response_class=Response)
async def delete_category(
    category_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(StoryElementCategory, category_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Category not found")
    el_count = int(
        (
            await db.execute(
                select(func.count()).select_from(StoryElement).where(
                    StoryElement.category_id == category_id
                )
            )
        ).scalar_one()
    )
    if el_count > 0:
        raise HTTPException(status_code=400, detail="Category still has elements")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)


# —— Subcategories ——


@router.get("/element-subcategories", response_model=SubcategoryListOut)
async def list_subcategories(
    category_id: str | None = Query(default=None),
    canonical_only: bool = Query(default=False),
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> SubcategoryListOut:
    await upsert_canonical_taxonomy(db)
    q = select(StoryElementSubcategory).order_by(
        StoryElementSubcategory.sort_order, StoryElementSubcategory.id
    )
    if category_id:
        q = q.where(StoryElementSubcategory.category_id == category_id)
    if canonical_only:
        q = q.where(StoryElementSubcategory.generation_brief.is_not(None))
    rows = (await db.execute(q)).scalars().all()
    items = [_sub_out(r) for r in rows]
    return SubcategoryListOut(items=items, total=len(items))


@router.post("/element-subcategories", response_model=SubcategoryOut, status_code=201)
async def create_subcategory(
    body: SubcategoryCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> SubcategoryOut:
    pid = _check_id(body.id)
    cat_id = _check_id(body.category_id)
    if await db.get(StoryElementCategory, cat_id) is None:
        raise HTTPException(status_code=400, detail="category_id not found")
    if await db.get(StoryElementSubcategory, pid) is not None:
        raise HTTPException(status_code=409, detail="Subcategory id already exists")
    row = StoryElementSubcategory(
        id=pid,
        category_id=cat_id,
        label_zh=body.label_zh.strip(),
        label_en=(body.label_en or "").strip(),
        generation_brief=(body.generation_brief or "").strip() or None,
        id_prefix=(body.id_prefix or "").strip().lower() or None,
        sort_order=body.sort_order,
        enabled=body.enabled,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return _sub_out(row)


@router.patch("/element-subcategories/{subcategory_id}", response_model=SubcategoryOut)
async def patch_subcategory(
    subcategory_id: str,
    body: SubcategoryPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> SubcategoryOut:
    row = await db.get(StoryElementSubcategory, subcategory_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Subcategory not found")
    data = body.model_dump(exclude_unset=True)
    if "category_id" in data and data["category_id"] is not None:
        cat_id = _check_id(data["category_id"])
        if await db.get(StoryElementCategory, cat_id) is None:
            raise HTTPException(status_code=400, detail="category_id not found")
        row.category_id = cat_id
    if "label_zh" in data and data["label_zh"] is not None:
        row.label_zh = data["label_zh"].strip()
    if "label_en" in data and data["label_en"] is not None:
        row.label_en = data["label_en"].strip()
    if "generation_brief" in data:
        row.generation_brief = (data["generation_brief"] or "").strip() or None
    if "id_prefix" in data:
        row.id_prefix = (data["id_prefix"] or "").strip().lower() or None
    if "sort_order" in data and data["sort_order"] is not None:
        row.sort_order = int(data["sort_order"])
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    await db.commit()
    await db.refresh(row)
    return _sub_out(row)


@router.delete(
    "/element-subcategories/{subcategory_id}", status_code=204, response_class=Response
)
async def delete_subcategory(
    subcategory_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(StoryElementSubcategory, subcategory_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Subcategory not found")
    el_count = int(
        (
            await db.execute(
                select(func.count()).select_from(StoryElement).where(
                    StoryElement.subcategory_id == subcategory_id
                )
            )
        ).scalar_one()
    )
    if el_count > 0:
        raise HTTPException(status_code=400, detail="Subcategory still has elements")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)


# —— Elements ——


@router.get("/elements/generate-defaults", response_model=GenerateDefaultsOut)
async def get_generate_defaults(
    _: str = Depends(require_admin),
) -> GenerateDefaultsOut:
    data = generate_defaults()
    return GenerateDefaultsOut(
        providers=data["providers"],
        defaults=data["defaults"],
        age_stages=data.get("age_stages") or [],
        subcategory_target_total=int(data.get("subcategory_target_total") or 100),
        stage_targets=data.get("stage_targets") or {},
    )


@router.get("/elements/inventory", response_model=InventoryOut)
async def get_element_inventory(
    subcategory_id: str = Query(min_length=2, max_length=64),
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> InventoryOut:
    await upsert_canonical_taxonomy(db)
    sub = await db.get(StoryElementSubcategory, subcategory_id.strip())
    if sub is None:
        raise HTTPException(status_code=404, detail="Subcategory not found")
    inv = await inventory_for_subcategory(db, subcategory_id.strip())
    return InventoryOut(**inv)


@router.post("/elements/generate", response_model=ElementGenerateOut)
async def generate_elements(
    body: ElementGenerateBody,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ElementGenerateOut:
    await upsert_canonical_taxonomy(db)
    provider = body.provider.strip().lower()
    if provider not in ELEMENT_GEN_PROVIDERS:
        raise HTTPException(
            status_code=400,
            detail=f"provider must be one of {', '.join(ELEMENT_GEN_PROVIDERS)}",
        )
    age_stage = _validate_age_stage(body.age_stage)
    try:
        result = await run_element_generation(
            db,
            subcategory_id=body.subcategory_id.strip(),
            age_stage=age_stage,
            provider=provider,
            model=body.model.strip(),
            count=body.count,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return ElementGenerateOut(**result)


@router.get("/elements", response_model=ElementListOut)
async def list_elements(
    category_id: str | None = Query(default=None),
    subcategory_id: str | None = Query(default=None),
    enabled: bool | None = Query(default=None),
    age_stage: str | None = Query(default=None),
    age_years: int | None = Query(default=None, ge=0, le=18),
    q: str | None = Query(default=None, max_length=128),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ElementListOut:
    await upsert_canonical_taxonomy(db)
    filters = []
    if category_id:
        filters.append(StoryElement.category_id == category_id)
    if subcategory_id:
        filters.append(StoryElement.subcategory_id == subcategory_id)
    if enabled is not None:
        filters.append(StoryElement.enabled.is_(enabled))
    if age_stage:
        filters.append(StoryElement.age_stage == _validate_age_stage(age_stage))
    elif age_years is not None:
        filters.append(StoryElement.age_stage == age_stage_for_years(age_years))
    if q and q.strip():
        like = f"%{q.strip()}%"
        filters.append(
            or_(
                StoryElement.name.ilike(like),
                StoryElement.id.ilike(like),
                StoryElement.description.ilike(like),
            )
        )
    count_q = select(func.count()).select_from(StoryElement)
    list_q = (
        select(StoryElement)
        .options(
            selectinload(StoryElement.category),
            selectinload(StoryElement.subcategory),
        )
        .order_by(StoryElement.category_id, StoryElement.id)
        .offset(offset)
        .limit(limit)
    )
    if filters:
        count_q = count_q.where(*filters)
        list_q = list_q.where(*filters)
    total = int((await db.execute(count_q)).scalar_one())
    rows = (await db.execute(list_q)).scalars().all()
    return ElementListOut(items=[_element_out(r) for r in rows], total=total)


@router.get("/elements/{element_id}", response_model=ElementOut)
async def get_element(
    element_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ElementOut:
    row = (
        await db.execute(
            select(StoryElement)
            .where(StoryElement.id == element_id)
            .options(
                selectinload(StoryElement.category),
                selectinload(StoryElement.subcategory),
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Element not found")
    return _element_out(row)


@router.post("/elements", response_model=ElementOut, status_code=201)
async def create_element(
    body: ElementCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ElementOut:
    pid = _check_id(body.id)
    cat_id = _check_id(body.category_id)
    sub_id = _check_id(body.subcategory_id)
    await _validate_taxonomy(db, cat_id, sub_id)
    stage = _validate_age_stage(body.age_stage)
    if await db.get(StoryElement, pid) is not None:
        raise HTTPException(status_code=409, detail="Element id already exists")
    row = StoryElement(
        id=pid,
        category_id=cat_id,
        subcategory_id=sub_id,
        name=body.name.strip(),
        description=body.description.strip(),
        age_stage=stage,
        enabled=body.enabled,
    )
    db.add(row)
    await db.commit()
    row = (
        await db.execute(
            select(StoryElement)
            .where(StoryElement.id == pid)
            .options(
                selectinload(StoryElement.category),
                selectinload(StoryElement.subcategory),
            )
        )
    ).scalar_one()
    return _element_out(row)


@router.patch("/elements/{element_id}", response_model=ElementOut)
async def patch_element(
    element_id: str,
    body: ElementPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ElementOut:
    row = await db.get(StoryElement, element_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Element not found")
    data = body.model_dump(exclude_unset=True)
    cat_id = data.get("category_id", row.category_id)
    sub_id = data.get("subcategory_id", row.subcategory_id)
    if "category_id" in data or "subcategory_id" in data:
        cat_id = _check_id(cat_id)
        sub_id = _check_id(sub_id)
        await _validate_taxonomy(db, cat_id, sub_id)
        row.category_id = cat_id
        row.subcategory_id = sub_id
    if "name" in data and data["name"] is not None:
        row.name = data["name"].strip()
    if "description" in data and data["description"] is not None:
        row.description = data["description"].strip()
    if "age_stage" in data and data["age_stage"] is not None:
        row.age_stage = _validate_age_stage(data["age_stage"])
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    await db.commit()
    row = (
        await db.execute(
            select(StoryElement)
            .where(StoryElement.id == element_id)
            .options(
                selectinload(StoryElement.category),
                selectinload(StoryElement.subcategory),
            )
        )
    ).scalar_one()
    return _element_out(row)


@router.delete("/elements/{element_id}", status_code=204, response_class=Response)
async def delete_element(
    element_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(StoryElement, element_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Element not found")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)


@router.post("/elements/import", response_model=ElementImportOut)
async def import_elements(
    body: ElementImportBody,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> ElementImportOut:
    await upsert_canonical_taxonomy(db)
    created = 0
    updated = 0
    for item in body.items:
        pid = _check_id(item.id)
        cat_id = _check_id(item.category_id)
        sub_id = _check_id(item.subcategory_id)
        await _validate_taxonomy(db, cat_id, sub_id)
        stage = _validate_age_stage(item.age_stage)
        row = await db.get(StoryElement, pid)
        if row is None:
            db.add(
                StoryElement(
                    id=pid,
                    category_id=cat_id,
                    subcategory_id=sub_id,
                    name=item.name.strip(),
                    description=item.description.strip(),
                    age_stage=stage,
                    enabled=item.enabled,
                )
            )
            created += 1
        else:
            row.category_id = cat_id
            row.subcategory_id = sub_id
            row.name = item.name.strip()
            row.description = item.description.strip()
            row.age_stage = stage
            row.enabled = item.enabled
            updated += 1
    await db.commit()
    return ElementImportOut(created=created, updated=updated, total=created + updated)
