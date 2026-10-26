"""Admin CRUD for LLM routing rules (bind to llm_models instances)."""

from __future__ import annotations

import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Response
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.llm_model import LlmModel
from app.models.llm_routing_rule import LlmRoutingRule
from app.services.llm_agents import AGENT_IDS
from app.services.llm_routing import TIERS

router = APIRouter(prefix="/llm-routing-rules", tags=["admin-llm-routing"])


class LlmModelBrief(BaseModel):
    id: int
    provider: str
    model_id: str
    tier: str
    label_zh: str
    enabled: bool


class LlmRoutingRuleOut(BaseModel):
    id: int
    stage: str
    priority: int
    match_json: str
    target_llm_model_id: int | None
    target_model: LlmModelBrief | None = None
    enabled: bool
    label_zh: str
    updated_at: datetime | None = None


class LlmRoutingRuleListOut(BaseModel):
    items: list[LlmRoutingRuleOut]
    total: int
    tiers: list[str] = list(TIERS)
    stages: list[str] = list(AGENT_IDS)
    models: list[LlmModelBrief] = []
    priority_hint: str = (
        "force runtime story_model > Agent model > 路由(绑定 llm_models) > env"
    )


class LlmRoutingRuleCreate(BaseModel):
    stage: str = Field(max_length=64)
    priority: int = 100
    match_json: str = "{}"
    target_llm_model_id: int = Field(ge=1)
    enabled: bool = True
    label_zh: str = Field(default="", max_length=128)


class LlmRoutingRulePatch(BaseModel):
    stage: str | None = Field(default=None, max_length=64)
    priority: int | None = None
    match_json: str | None = None
    target_llm_model_id: int | None = Field(default=None, ge=1)
    enabled: bool | None = None
    label_zh: str | None = Field(default=None, max_length=128)


def _model_brief(row: LlmModel) -> LlmModelBrief:
    return LlmModelBrief(
        id=row.id,
        provider=row.provider,
        model_id=row.model_id,
        tier=row.tier,
        label_zh=row.label_zh or "",
        enabled=bool(row.enabled),
    )


async def _out(db: AsyncSession, row: LlmRoutingRule) -> LlmRoutingRuleOut:
    brief: LlmModelBrief | None = None
    if row.target_llm_model_id is not None:
        model = await db.get(LlmModel, int(row.target_llm_model_id))
        if model is not None:
            brief = _model_brief(model)
    return LlmRoutingRuleOut(
        id=row.id,
        stage=row.stage,
        priority=int(row.priority or 0),
        match_json=row.match_json or "{}",
        target_llm_model_id=row.target_llm_model_id,
        target_model=brief,
        enabled=bool(row.enabled),
        label_zh=row.label_zh or "",
        updated_at=row.updated_at,
    )


def _validate_stage(stage: str) -> str:
    s = stage.strip()
    if s not in AGENT_IDS:
        raise HTTPException(status_code=400, detail=f"Invalid stage: {stage}")
    return s


async def _require_model(db: AsyncSession, model_id: int) -> LlmModel:
    row = await db.get(LlmModel, int(model_id))
    if row is None:
        raise HTTPException(status_code=400, detail="target_llm_model_id not found")
    return row


def _normalize_match_json(raw: str) -> str:
    text = (raw or "").strip() or "{}"
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="match_json must be JSON") from exc
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="match_json must be a JSON object")
    return json.dumps(data, ensure_ascii=False)


@router.get("", response_model=LlmRoutingRuleListOut)
async def list_routing_rules(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmRoutingRuleListOut:
    rows = (
        await db.execute(
            select(LlmRoutingRule).order_by(
                LlmRoutingRule.stage.asc(),
                LlmRoutingRule.priority.asc(),
                LlmRoutingRule.id.asc(),
            )
        )
    ).scalars().all()
    models = (
        await db.execute(
            select(LlmModel).order_by(
                LlmModel.provider.asc(),
                LlmModel.tier.asc(),
                LlmModel.sort_order.asc(),
                LlmModel.id.asc(),
            )
        )
    ).scalars().all()
    items = [await _out(db, r) for r in rows]
    return LlmRoutingRuleListOut(
        items=items,
        total=len(items),
        models=[_model_brief(m) for m in models],
    )


@router.post("", response_model=LlmRoutingRuleOut, status_code=201)
async def create_routing_rule(
    body: LlmRoutingRuleCreate,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmRoutingRuleOut:
    stage = _validate_stage(body.stage)
    await _require_model(db, body.target_llm_model_id)
    row = LlmRoutingRule(
        stage=stage,
        priority=int(body.priority),
        match_json=_normalize_match_json(body.match_json),
        target_llm_model_id=int(body.target_llm_model_id),
        enabled=bool(body.enabled),
        label_zh=(body.label_zh or "").strip(),
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return await _out(db, row)


@router.patch("/{rule_id}", response_model=LlmRoutingRuleOut)
async def patch_routing_rule(
    rule_id: int,
    body: LlmRoutingRulePatch,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmRoutingRuleOut:
    row = await db.get(LlmRoutingRule, rule_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Rule not found")
    data = body.model_dump(exclude_unset=True)

    if "stage" in data and data["stage"] is not None:
        row.stage = _validate_stage(data["stage"])
    if "target_llm_model_id" in data and data["target_llm_model_id"] is not None:
        await _require_model(db, int(data["target_llm_model_id"]))
        row.target_llm_model_id = int(data["target_llm_model_id"])
    if "priority" in data and data["priority"] is not None:
        row.priority = int(data["priority"])
    if "match_json" in data and data["match_json"] is not None:
        row.match_json = _normalize_match_json(data["match_json"])
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])
    if "label_zh" in data and data["label_zh"] is not None:
        row.label_zh = data["label_zh"].strip()

    await db.commit()
    await db.refresh(row)
    return await _out(db, row)


@router.delete("/{rule_id}", status_code=204, response_class=Response)
async def delete_routing_rule(
    rule_id: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> Response:
    row = await db.get(LlmRoutingRule, rule_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Rule not found")
    await db.delete(row)
    await db.commit()
    return Response(status_code=204)
