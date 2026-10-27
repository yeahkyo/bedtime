from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.waitlist import WaitlistLead

router = APIRouter(prefix="/waitlist", tags=["admin-waitlist"])


class WaitlistLeadOut(BaseModel):
    id: int
    email: str
    device: str
    note: str | None
    created_at: str | None
    updated_at: str | None


class WaitlistListOut(BaseModel):
    items: list[WaitlistLeadOut]
    total: int
    page: int
    page_size: int


def _out(row: WaitlistLead) -> WaitlistLeadOut:
    return WaitlistLeadOut(
        id=row.id,
        email=row.email,
        device=row.device,
        note=row.note,
        created_at=row.created_at.isoformat() if row.created_at else None,
        updated_at=row.updated_at.isoformat() if row.updated_at else None,
    )


@router.get("", response_model=WaitlistListOut)
async def list_waitlist(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    _: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> WaitlistListOut:
    total = int((await db.execute(select(func.count()).select_from(WaitlistLead))).scalar_one())
    offset = (page - 1) * page_size
    rows = (
        await db.execute(
            select(WaitlistLead)
            .order_by(WaitlistLead.created_at.desc())
            .offset(offset)
            .limit(page_size)
        )
    ).scalars().all()
    return WaitlistListOut(
        items=[_out(r) for r in rows],
        total=total,
        page=page,
        page_size=page_size,
    )
