"""Admin CRUD for LLM model registry."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.llm_model import LlmModel
from app.services.llm_routing import TIERS
from app.services.provider_settings import STORY_PROVIDERS

router = APIRouter(prefix="/llm-models", tags=["admin-llm-models"])


class LlmModelOut(BaseModel):
    id: int
    provider: str
    model_id: str
    tier: str
    label_zh: str
    enabled: bool
    sort_order: int
    notes: str | None = None
    updated_at: datetime | None = None


class LlmModelListOut(BaseModel):
    items: list[LlmModelOut]
    total: int
    tiers: list[str] = list(TIERS)
    providers: list[str] = list(STORY_PROVIDERS)


class LlmModelCreate(BaseModel):
    provider: str = Field(max_length=32)
    model_id: str = Field(max_length=128)
    tier: str = Field(max_length=16)
    label_zh: str = Field(default="", max_length=128)
    enabled: bool = True
    sort_order: int = 0
    notes: str | None = None


class LlmModelPatch(BaseModel):
    provider: str | None = Field(default=None, max_length=32)
    model_id: str | None = Field(default=None, max_length=128)
    tier: str | None = Field(default=None, max_length=16)
    label_zh: str | None = Field(default=None, max_length=128)
    enabled: bool | None = None
    sort_order: int | None = None
    notes: str | None = None
    clear_notes: bool = False


def _out(row: LlmModel) -> LlmModelOut:
    return LlmModelOut(
        id=row.id,
        provider=row.provider,
        model_id=row.model_id,
        tier=row.tier,
        label_zh=row.label_zh or "",
        enabled=bool(row.enabled),
        sort_order=int(row.sort_order or 0),
        notes=row.notes,
        updated_at=row.updated_at,
    )


def _validate_provider_tier(provider: str, tier: str) -> tuple[str, str]:
    p = provider.strip().lower()
    t = tier.strip().lower()
    if p not in STORY_PROVIDERS:
        raise HTTPException(status_code=400, detail=f"Invalid provider: {provider}")
    if t not in TIERS:
        raise HTTPException(status_code=400, detail=f"Invalid tier: {tier}")
    return p, t


@router.get("", response_model=LlmModelListOut)
async def list_llm_models(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmModelListOut:
    rows = (
        await db.execute(
            select(LlmModel).order_by(
                LlmModel.provider.asc(),
                LlmModel.tier.asc(),
                LlmModel.sort_order.asc(),
                LlmModel.id.asc(),
            )
        )
    ).scalars().all()
    items = [_out(r) for r in rows]
    return LlmModelListOut(items=items, total=len(items))


@router.post("", response_model=LlmModelOut, status_code=201)
async def create_llm_model(
    body: LlmModelCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmModelOut:
    provider, tier = _validate_provider_tier(body.provider, body.tier)
    model_id = body.model_id.strip()
    if not model_id:
        raise HTTPException(status_code=400, detail="model_id required")
    row = LlmModel(
        provider=provider,
        model_id=model_id,
        tier=tier,
        label_zh=(body.label_zh or "").strip() or f"{provider} · {tier}",
        enabled=bool(body.enabled),
        sort_order=int(body.sort_order),
        notes=(body.notes or None),
    )
    db.add(row)
    try:
        await db.commit()
    except Exception as exc:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Duplicate provider/tier/model_id") from exc
    await db.refresh(row)
    return _out(row)


@router.patch("/{model_pk}", response_model=LlmModelOut)
async def patch_llm_model(
    model_pk: int,
    body: LlmModelPatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmModelOut:
    row = await db.get(LlmModel, model_pk)
    if row is None:
        raise HTTPException(status_code=404, detail="Model not found")
    data = body.model_dump(exclude_unset=True)
    data.pop("clear_notes", None)

    provider = row.provider
    tier = row.tier
    if "provider" in data and data["provider"] is not None:
        provider = data["provider"].strip().lower()
    if "tier" in data and data["tier"] is not None:
        tier = data["tier"].strip().lower()
    if "provider" in data or "tier" in data:
        provider, tier = _validate_provider_tier(provider, tier)
        row.provider = provider
        row.tier = tier

    if "model_id" in data and data["model_id"] is not None:
        mid = data["model_id"].strip()
        if not mid:
            raise HTTPException(status_code=400, detail="model_id required")
        row.model_id = mid
    if "label_zh" in data and data["label_zh"] is not None:
        row.label_zh = data["label_zh"].strip()
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    if "sort_order" in data and data["sort_order"] is not None:
        row.sort_order = int(data["sort_order"])
    if body.clear_notes:
        row.notes = None
    elif "notes" in data:
        row.notes = data["notes"]

    try:
        await db.commit()
    except Exception as exc:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Duplicate provider/tier/model_id") from exc
    await db.refresh(row)
    return _out(row)


@router.delete("/{model_pk}", status_code=204, response_class=Response)
async def delete_llm_model(
    model_pk: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(LlmModel, model_pk)
    if row is None:
        raise HTTPException(status_code=404, detail="Model not found")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)
