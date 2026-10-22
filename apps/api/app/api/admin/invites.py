import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import require_admin
from app.models.invite import InviteCode

router = APIRouter(prefix="/invites", tags=["admin-invites"])


class InviteOut(BaseModel):
    id: int
    code: str
    note: str | None
    created_by: str | None
    created_at: str | None
    expires_at: str | None
    used_at: str | None
    used_by_user_id: int | None
    revoked_at: str | None
    status: str


class InviteListOut(BaseModel):
    items: list[InviteOut]
    total: int
    page: int
    page_size: int


class InviteCreateIn(BaseModel):
    count: int = Field(default=1, ge=1, le=50)
    note: str | None = Field(default=None, max_length=256)
    expires_in_days: int | None = Field(default=30, ge=1, le=365)


class InviteCreateOut(BaseModel):
    items: list[InviteOut]


def _status(inv: InviteCode, now: datetime) -> str:
    if inv.revoked_at is not None:
        return "revoked"
    if inv.used_at is not None:
        return "used"
    if inv.expires_at is not None:
        exp = inv.expires_at
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        if exp <= now:
            return "expired"
    return "unused"


def _out(inv: InviteCode, now: datetime) -> InviteOut:
    return InviteOut(
        id=inv.id,
        code=inv.code,
        note=inv.note,
        created_by=inv.created_by,
        created_at=inv.created_at.isoformat() if inv.created_at else None,
        expires_at=inv.expires_at.isoformat() if inv.expires_at else None,
        used_at=inv.used_at.isoformat() if inv.used_at else None,
        used_by_user_id=inv.used_by_user_id,
        revoked_at=inv.revoked_at.isoformat() if inv.revoked_at else None,
        status=_status(inv, now),
    )


def _gen_code() -> str:
    # e.g. LULL-A1B2C3D4
    return f"LULL-{secrets.token_hex(4).upper()}"


@router.get("", response_model=InviteListOut)
async def list_invites(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    status: str | None = Query(None, description="unused|used|revoked|expired"),
    admin: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> InviteListOut:
    _ = admin
    now = datetime.now(timezone.utc)
    rows = (
        await db.execute(select(InviteCode).order_by(InviteCode.id.desc()))
    ).scalars().all()
    filtered = [_out(r, now) for r in rows]
    if status and status.strip():
        want = status.strip().lower()
        filtered = [x for x in filtered if x.status == want]
    total = len(filtered)
    start = (page - 1) * page_size
    items = filtered[start : start + page_size]
    return InviteListOut(items=items, total=total, page=page, page_size=page_size)


@router.post("", response_model=InviteCreateOut)
async def create_invites(
    body: InviteCreateIn,
    admin: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> InviteCreateOut:
    now = datetime.now(timezone.utc)
    expires_at = None
    if body.expires_in_days is not None:
        expires_at = now + timedelta(days=body.expires_in_days)
    created: list[InviteCode] = []
    for _ in range(body.count):
        for _attempt in range(8):
            code = _gen_code()
            exists = (
                await db.execute(select(func.count()).select_from(InviteCode).where(InviteCode.code == code))
            ).scalar_one()
            if int(exists) == 0:
                break
        else:
            raise HTTPException(status_code=500, detail="Failed to generate unique invite code")
        row = InviteCode(
            code=code,
            note=body.note,
            created_by=admin,
            expires_at=expires_at,
        )
        db.add(row)
        created.append(row)
    await db.commit()
    for row in created:
        await db.refresh(row)
    return InviteCreateOut(items=[_out(r, now) for r in created])


@router.post("/{invite_id}/revoke", response_model=InviteOut)
async def revoke_invite(
    invite_id: int,
    admin: str = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
) -> InviteOut:
    _ = admin
    inv = await db.get(InviteCode, invite_id)
    if inv is None:
        raise HTTPException(status_code=404, detail="Invite not found")
    now = datetime.now(timezone.utc)
    if inv.used_at is not None:
        raise HTTPException(status_code=400, detail="Invite already used")
    if inv.revoked_at is None:
        inv.revoked_at = now
        await db.commit()
        await db.refresh(inv)
    return _out(inv, now)
