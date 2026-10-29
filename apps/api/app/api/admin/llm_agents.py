"""Admin CRUD for configurable LLM agent prompts."""

from __future__ import annotations

import json
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.llm_agent import LlmAgent
from app.models.llm_agent_version import LlmAgentVersion
from app.services.llm_agents import (
    AGENT_IDS,
    CODE_DEFAULTS,
    apply_prompt_fields_and_version,
    reset_agent_to_code_default,
    restore_agent_version,
    seed_llm_agents_if_missing,
)

router = APIRouter(prefix="/llm-agents", tags=["admin-llm-agents"])


class PlaceholderOut(BaseModel):
    name: str
    description: str = ""


class LlmAgentOut(BaseModel):
    id: str
    label_zh: str
    description: str
    provider: str | None
    model: str | None
    system_prompt: str
    user_prompt_template: str
    max_tokens: int | None
    timeout_seconds: int | None
    temperature: float | None
    placeholders: list[PlaceholderOut]
    enabled: bool
    updated_at: datetime | None = None


class LlmAgentListOut(BaseModel):
    items: list[LlmAgentOut]
    total: int
    priority_hint: str = (
        "force runtime story_model > Agent model > 路由(绑定 llm_models) > env"
    )


class LlmAgentPatch(BaseModel):
    label_zh: str | None = Field(default=None, max_length=128)
    description: str | None = None
    provider: str | None = Field(default=None, max_length=32)
    model: str | None = Field(default=None, max_length=128)
    system_prompt: str | None = None
    user_prompt_template: str | None = None
    max_tokens: int | None = Field(default=None, ge=1, le=128000)
    timeout_seconds: int | None = Field(default=None, ge=1, le=3600)
    temperature: float | None = Field(default=None, ge=0, le=2)
    enabled: bool | None = None
    clear_provider: bool = False
    clear_model: bool = False
    clear_max_tokens: bool = False
    clear_timeout_seconds: bool = False
    clear_temperature: bool = False
    version_note: str | None = Field(default=None, max_length=256)


class LlmAgentVersionSummary(BaseModel):
    version: int
    note: str
    source: str
    created_by: str
    created_at: datetime | None = None
    system_prompt_preview: str = ""
    temperature: float | None = None
    max_tokens: int | None = None
    timeout_seconds: int | None = None


class LlmAgentVersionListOut(BaseModel):
    items: list[LlmAgentVersionSummary]
    total: int


class LlmAgentVersionOut(BaseModel):
    agent_id: str
    version: int
    note: str
    source: str
    created_by: str
    created_at: datetime | None = None
    system_prompt: str
    user_prompt_template: str
    temperature: float | None
    max_tokens: int | None
    timeout_seconds: int | None


class RestoreBody(BaseModel):
    note: str | None = Field(default=None, max_length=256)


class LabSaveBody(BaseModel):
    system_prompt: str
    user_prompt_template: str
    temperature: float | None = Field(default=None, ge=0, le=2)
    clear_temperature: bool = False
    max_tokens: int | None = Field(default=None, ge=1, le=128000)
    clear_max_tokens: bool = False
    timeout_seconds: int | None = Field(default=None, ge=1, le=3600)
    clear_timeout_seconds: bool = False
    version_note: str | None = Field(default=None, max_length=256)


def _parse_placeholders(raw: str | None) -> list[PlaceholderOut]:
    try:
        data = json.loads(raw or "[]")
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    out: list[PlaceholderOut] = []
    for item in data:
        if isinstance(item, dict) and item.get("name"):
            out.append(
                PlaceholderOut(
                    name=str(item["name"]),
                    description=str(item.get("description") or ""),
                )
            )
    return out


def _out(row: LlmAgent) -> LlmAgentOut:
    return LlmAgentOut(
        id=row.id,
        label_zh=row.label_zh or row.id,
        description=row.description or "",
        provider=row.provider,
        model=row.model,
        system_prompt=row.system_prompt or "",
        user_prompt_template=row.user_prompt_template or "{{user_payload}}",
        max_tokens=row.max_tokens,
        timeout_seconds=row.timeout_seconds,
        temperature=row.temperature,
        placeholders=_parse_placeholders(row.placeholders_json),
        enabled=bool(row.enabled),
        updated_at=row.updated_at,
    )


def _version_summary(row: LlmAgentVersion) -> LlmAgentVersionSummary:
    sys_p = row.system_prompt or ""
    preview = sys_p[:120] + ("…" if len(sys_p) > 120 else "")
    return LlmAgentVersionSummary(
        version=row.version,
        note=row.note or "",
        source=row.source or "",
        created_by=row.created_by or "",
        created_at=row.created_at,
        system_prompt_preview=preview,
        temperature=row.temperature,
        max_tokens=row.max_tokens,
        timeout_seconds=row.timeout_seconds,
    )


def _version_out(row: LlmAgentVersion) -> LlmAgentVersionOut:
    return LlmAgentVersionOut(
        agent_id=row.agent_id,
        version=row.version,
        note=row.note or "",
        source=row.source or "",
        created_by=row.created_by or "",
        created_at=row.created_at,
        system_prompt=row.system_prompt or "",
        user_prompt_template=row.user_prompt_template or "{{user_payload}}",
        temperature=row.temperature,
        max_tokens=row.max_tokens,
        timeout_seconds=row.timeout_seconds,
    )


def _prompt_fields_in_patch(body: LlmAgentPatch, data: dict) -> bool:
    if any(
        k in data
        for k in (
            "system_prompt",
            "user_prompt_template",
            "temperature",
            "max_tokens",
            "timeout_seconds",
        )
    ):
        return True
    return bool(
        body.clear_temperature
        or body.clear_max_tokens
        or body.clear_timeout_seconds
    )


@router.get("", response_model=LlmAgentListOut)
async def list_agents(
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentListOut:
    await seed_llm_agents_if_missing(db)
    items: list[LlmAgentOut] = []
    for agent_id in AGENT_IDS:
        row = await db.get(LlmAgent, agent_id)
        if row is None:
            # Should not happen after seed; synthesize from code defaults.
            d = CODE_DEFAULTS[agent_id]
            items.append(
                LlmAgentOut(
                    id=agent_id,
                    label_zh=d["label_zh"],
                    description=d["description"],
                    provider=d.get("provider"),
                    model=d.get("model"),
                    system_prompt=d["system_prompt"],
                    user_prompt_template=d.get("user_prompt_template") or "{{user_payload}}",
                    max_tokens=d.get("max_tokens"),
                    timeout_seconds=d.get("timeout_seconds"),
                    temperature=d.get("temperature"),
                    placeholders=_parse_placeholders(d["placeholders_json"]),
                    enabled=True,
                    updated_at=None,
                )
            )
        else:
            items.append(_out(row))
    return LlmAgentListOut(items=items, total=len(items))


@router.get("/{agent_id}", response_model=LlmAgentOut)
async def get_agent_admin(
    agent_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentOut:
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    await seed_llm_agents_if_missing(db)
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Agent not found")
    return _out(row)


@router.patch("/{agent_id}", response_model=LlmAgentOut)
async def patch_agent(
    agent_id: str,
    body: LlmAgentPatch,
    operator: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentOut:
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    await seed_llm_agents_if_missing(db)
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Agent not found")

    data = body.model_dump(exclude_unset=True)
    for key in (
        "clear_provider",
        "clear_model",
        "clear_max_tokens",
        "clear_timeout_seconds",
        "clear_temperature",
        "version_note",
    ):
        data.pop(key, None)

    if body.clear_provider:
        row.provider = None
    elif "provider" in data:
        prov = data["provider"]
        row.provider = (prov or "").strip().lower() or None

    if body.clear_model:
        row.model = None
    elif "model" in data:
        mod = data["model"]
        row.model = (mod or "").strip() or None

    if "label_zh" in data and data["label_zh"] is not None:
        row.label_zh = data["label_zh"].strip()
    if "description" in data and data["description"] is not None:
        row.description = data["description"]
    if "enabled" in data and data["enabled"] is not None:
        row.enabled = bool(data["enabled"])

    if _prompt_fields_in_patch(body, data):
        await apply_prompt_fields_and_version(
            db,
            row,
            system_prompt=data.get("system_prompt"),
            user_prompt_template=data.get("user_prompt_template"),
            temperature=data.get("temperature"),
            max_tokens=data.get("max_tokens"),
            timeout_seconds=data.get("timeout_seconds"),
            clear_temperature=body.clear_temperature,
            clear_max_tokens=body.clear_max_tokens,
            clear_timeout_seconds=body.clear_timeout_seconds,
            source="admin_save",
            created_by=operator,
            note=(body.version_note or "").strip(),
        )
    else:
        # Metadata-only: still apply clears / numeric fields if somehow present
        if body.clear_max_tokens:
            row.max_tokens = None
        elif "max_tokens" in data:
            row.max_tokens = data["max_tokens"]
        if body.clear_timeout_seconds:
            row.timeout_seconds = None
        elif "timeout_seconds" in data:
            row.timeout_seconds = data["timeout_seconds"]
        if body.clear_temperature:
            row.temperature = None
        elif "temperature" in data:
            row.temperature = data["temperature"]

    await db.commit()
    await db.refresh(row)
    return _out(row)


@router.post("/{agent_id}/reset", response_model=LlmAgentOut)
async def reset_agent(
    agent_id: str,
    operator: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentOut:
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    try:
        row = await reset_agent_to_code_default(db, agent_id, created_by=operator)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return _out(row)


@router.get("/{agent_id}/versions", response_model=LlmAgentVersionListOut)
async def list_versions(
    agent_id: str,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentVersionListOut:
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    result = await db.execute(
        select(LlmAgentVersion)
        .where(LlmAgentVersion.agent_id == agent_id)
        .order_by(LlmAgentVersion.version.desc())
    )
    rows = list(result.scalars().all())
    return LlmAgentVersionListOut(
        items=[_version_summary(r) for r in rows],
        total=len(rows),
    )


@router.get("/{agent_id}/versions/{version}", response_model=LlmAgentVersionOut)
async def get_version(
    agent_id: str,
    version: int,
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentVersionOut:
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    result = await db.execute(
        select(LlmAgentVersion).where(
            LlmAgentVersion.agent_id == agent_id,
            LlmAgentVersion.version == version,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Version not found")
    return _version_out(row)


@router.post("/{agent_id}/versions/{version}/restore", response_model=LlmAgentOut)
async def restore_version(
    agent_id: str,
    version: int,
    body: RestoreBody | None = None,
    operator: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentOut:
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    note = (body.note if body else None) or ""
    try:
        row = await restore_agent_version(
            db,
            agent_id,
            version,
            created_by=operator,
            note=note.strip(),
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    return _out(row)


@router.post("/{agent_id}/lab-save", response_model=LlmAgentOut)
async def lab_save_agent(
    agent_id: str,
    body: LabSaveBody,
    operator: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> LlmAgentOut:
    """Write lab prompts/temperature to the live agent and insert a lab_save version."""
    if agent_id not in CODE_DEFAULTS:
        raise HTTPException(status_code=404, detail="Agent not found")
    await seed_llm_agents_if_missing(db)
    row = await db.get(LlmAgent, agent_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Agent not found")

    await apply_prompt_fields_and_version(
        db,
        row,
        system_prompt=body.system_prompt,
        user_prompt_template=body.user_prompt_template,
        temperature=body.temperature,
        max_tokens=body.max_tokens,
        timeout_seconds=body.timeout_seconds,
        clear_temperature=body.clear_temperature,
        clear_max_tokens=body.clear_max_tokens,
        clear_timeout_seconds=body.clear_timeout_seconds,
        source="lab_save",
        created_by=operator,
        note=(body.version_note or "").strip() or "试验台存为新版本",
    )
    await db.commit()
    await db.refresh(row)
    return _out(row)
