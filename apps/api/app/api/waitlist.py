import re
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.models.waitlist import WaitlistLead
from app.services.auth_rate_limit import rate_limit_auth_ip

router = APIRouter(prefix="/public/waitlist", tags=["public-waitlist"])

_EMAIL_RE = re.compile(r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$")
_ALLOWED_DEVICES = frozenset({"ios", "android", "both"})


class WaitlistIn(BaseModel):
    email: str = Field(..., min_length=3, max_length=320)
    device: str = Field(default="ios", max_length=32)
    note: str | None = Field(default=None, max_length=256)


class WaitlistOut(BaseModel):
    ok: bool = True
    email: str
    created: bool


def _normalize_email(raw: str) -> str:
    email = raw.strip().lower()
    if not _EMAIL_RE.match(email):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid email")
    return email


def _normalize_device(raw: str) -> str:
    device = (raw or "ios").strip().lower()
    if device not in _ALLOWED_DEVICES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid device")
    return device


async def _update_existing(
    db: AsyncSession,
    existing: WaitlistLead,
    *,
    email: str,
    device: str,
    note: str | None,
) -> WaitlistOut:
    existing.device = device
    existing.note = note
    existing.updated_at = datetime.now(timezone.utc)
    await db.commit()
    return WaitlistOut(ok=True, email=email, created=False)


@router.post("", response_model=WaitlistOut)
async def join_waitlist(
    body: WaitlistIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> WaitlistOut:
    await rate_limit_auth_ip(request, "waitlist", limit=10, window=60)
    email = _normalize_email(body.email)
    device = _normalize_device(body.device)
    note = body.note.strip() if body.note else None
    if note == "":
        note = None

    existing = (
        await db.execute(select(WaitlistLead).where(WaitlistLead.email == email))
    ).scalar_one_or_none()
    if existing is not None:
        return await _update_existing(db, existing, email=email, device=device, note=note)

    lead = WaitlistLead(email=email, device=device, note=note)
    db.add(lead)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raced = (
            await db.execute(select(WaitlistLead).where(WaitlistLead.email == email))
        ).scalar_one_or_none()
        if raced is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Could not save waitlist entry",
            )
        return await _update_existing(db, raced, email=email, device=device, note=note)
    return WaitlistOut(ok=True, email=email, created=True)
