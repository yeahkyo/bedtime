import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.child import Child
from app.models.user import User
from app.models.voice import VoicePrefs
from app.schemas.common import ChildCreate, ChildOut, ChildUpdate, VoicePrefsUpdate
from app.services.voice_settings import resolve_voice_settings


router = APIRouter(prefix="/children", tags=["children"])


def _to_out(child: Child) -> ChildOut:
    interests: list[str] = []
    if child.interests_json:
        interests = json.loads(child.interests_json)
    return ChildOut(id=child.id, nickname=child.nickname, age_band=child.age_band, interests=interests)


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
    child = Child(
        user_id=user.id,
        nickname=body.nickname,
        age_band=body.age_band,
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
    if body.age_band is not None:
        child.age_band = body.age_band
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
