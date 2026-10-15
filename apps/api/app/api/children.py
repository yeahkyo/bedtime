import json
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.user import User
from app.models.voice import VoicePrefs
from app.schemas.common import ChildCreate, ChildOut, ChildUpdate, VoicePrefsUpdate
from app.services.child_profile import (
    approximate_birth_date_from_age_band,
    normalize_gender,
    sync_age_band,
)
from app.services.voice_settings import resolve_voice_settings


router = APIRouter(prefix="/children", tags=["children"])


def _resolve_birth_and_band(
    *,
    birth_date: date | None,
    age_band: str | None,
    existing_birth: date | None = None,
    existing_band: str | None = None,
) -> tuple[date | None, str]:
    if birth_date is not None:
        if birth_date > date.today():
            raise HTTPException(status_code=400, detail="birth_date cannot be in the future")
        return birth_date, sync_age_band(birth_date)
    if age_band is not None:
        approx = approximate_birth_date_from_age_band(age_band)
        return approx, sync_age_band(approx, age_band)
    if existing_birth is not None:
        return existing_birth, sync_age_band(existing_birth, existing_band)
    if existing_band:
        approx = approximate_birth_date_from_age_band(existing_band)
        return approx, sync_age_band(approx, existing_band)
    # Default: ~4 years old
    approx = approximate_birth_date_from_age_band("3-5")
    return approx, "3-5"


def _to_out(child: Child) -> ChildOut:
    interests: list[str] = []
    if child.interests_json:
        interests = json.loads(child.interests_json)
    band = sync_age_band(child.birth_date, child.age_band)
    return ChildOut(
        id=child.id,
        nickname=child.nickname,
        birth_date=child.birth_date,
        age_band=band,
        gender=normalize_gender(child.gender),
        intro=child.intro,
        interests=interests,
    )


@router.get("", response_model=list[ChildOut])
async def list_children(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> list[ChildOut]:
    rows = await db.execute(select(Child).where(Child.user_id == user.id))
    return [_to_out(c) for c in rows.scalars().all()]


@router.post("", response_model=ChildOut)
async def create_child(
    body: ChildCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
) -> ChildOut:
    birth, band = _resolve_birth_and_band(birth_date=body.birth_date, age_band=body.age_band)
    child = Child(
        user_id=user.id,
        nickname=body.nickname,
        birth_date=birth,
        age_band=band,
        gender=normalize_gender(body.gender),
        intro=(body.intro or "").strip() or None,
        interests_json=json.dumps(body.interests, ensure_ascii=False),
    )
    db.add(child)
    await db.flush()
    vs = resolve_voice_settings()
    db.add(
        VoicePrefs(
            child_id=child.id,
            speed=vs.speed,
            stability=vs.stability,
            style=vs.style,
            similarity_boost=vs.similarity_boost,
        )
    )
    await db.commit()
    await db.refresh(child)
    return _to_out(child)


@router.patch("/{child_id}", response_model=ChildOut)
async def update_child(
    child_id: int,
    body: ChildUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ChildOut:
    child = await db.get(Child, child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")
    if body.nickname is not None:
        child.nickname = body.nickname
    if body.birth_date is not None:
        birth, band = _resolve_birth_and_band(
            birth_date=body.birth_date,
            age_band=None,
            existing_birth=child.birth_date,
            existing_band=child.age_band,
        )
        child.birth_date = birth
        child.age_band = band
    elif body.age_band is not None:
        # Legacy clients may still PATCH age_band. Never overwrite a precise birth_date.
        if child.birth_date is not None:
            child.age_band = sync_age_band(child.birth_date)
        else:
            birth, band = _resolve_birth_and_band(
                birth_date=None,
                age_band=body.age_band,
                existing_birth=None,
                existing_band=child.age_band,
            )
            child.birth_date = birth
            child.age_band = band
    if body.gender is not None:
        child.gender = normalize_gender(body.gender)
    if body.intro is not None:
        child.intro = body.intro.strip() or None
    if body.interests is not None:
        child.interests_json = json.dumps(body.interests, ensure_ascii=False)
    await db.commit()
    await db.refresh(child)
    return _to_out(child)


@router.patch("/{child_id}/voice-prefs")
async def update_voice_prefs(
    child_id: int,
    body: VoicePrefsUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    child = await db.get(Child, child_id)
    if child is None or child.user_id != user.id:
        raise HTTPException(status_code=404, detail="Child not found")
    prefs = (
        await db.execute(select(VoicePrefs).where(VoicePrefs.child_id == child_id))
    ).scalar_one_or_none()
    vs = resolve_voice_settings(body.speed_tier, body.tone_preset, body.likeness_boost)
    if prefs is None:
        prefs = VoicePrefs(child_id=child_id)
        db.add(prefs)
    prefs.speed_tier = body.speed_tier
    prefs.tone_preset = body.tone_preset
    prefs.likeness_boost = body.likeness_boost
    prefs.default_voice_id = body.default_voice_id
    prefs.speed = vs.speed
    prefs.stability = vs.stability
    prefs.style = vs.style
    prefs.similarity_boost = vs.similarity_boost
    await db.commit()
    return {
        "speed_tier": prefs.speed_tier,
        "tone_preset": prefs.tone_preset,
        "likeness_boost": prefs.likeness_boost,
        "resolved": {
            "speed": prefs.speed,
            "stability": prefs.stability,
            "style": prefs.style,
            "similarity_boost": prefs.similarity_boost,
        },
    }
