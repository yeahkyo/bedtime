"""App CRUD for story roster characters (person / toy; child twin is auto)."""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.character import Character
from app.models.child import Child
from app.models.user import User
from app.schemas.common import CharacterCreate, CharacterOut, CharacterUpdate
from app.services.characters import (
    CLIENT_CREATABLE_KINDS,
    KIND_CHILD,
    KIND_PERSON,
    ensure_child_character,
    normalize_kind,
)

router = APIRouter(prefix="/characters", tags=["characters"])


def _to_out(row: Character) -> CharacterOut:
    return CharacterOut(
        id=row.id,
        kind=row.kind,
        name=row.name,
        related_child_id=row.related_child_id,
        relation=(row.relation or "").strip() or None,
        note=(row.note or "").strip() or None,
        listener_child_id=row.listener_child_id,
        enabled=bool(row.enabled),
    )


async def _owned_child(
    db: AsyncSession, *, user_id: int, child_id: int
) -> Child:
    child = await db.get(Child, child_id)
    if child is None or child.user_id != user_id:
        raise HTTPException(status_code=404, detail="Child not found")
    return child


@router.get("", response_model=list[CharacterOut])
async def list_characters(
    related_child_id: int | None = Query(default=None),
    include_disabled: bool = Query(default=False),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[CharacterOut]:
    # Light backfill: only the filtered child, or children still missing a twin.
    if related_child_id is not None:
        child = await _owned_child(db, user_id=user.id, child_id=related_child_id)
        await ensure_child_character(db, user_id=user.id, child=child)
        await db.commit()
    else:
        children = (
            await db.execute(select(Child).where(Child.user_id == user.id))
        ).scalars().all()
        twin_ids = set(
            (
                await db.execute(
                    select(Character.listener_child_id).where(
                        Character.user_id == user.id,
                        Character.kind == KIND_CHILD,
                        Character.listener_child_id.is_not(None),
                    )
                )
            )
            .scalars()
            .all()
        )
        created = False
        for child in children:
            if child.id in twin_ids:
                continue
            await ensure_child_character(db, user_id=user.id, child=child)
            created = True
        if created:
            await db.commit()

    q = select(Character).where(Character.user_id == user.id)
    if related_child_id is not None:
        q = q.where(Character.related_child_id == related_child_id)
    if not include_disabled:
        q = q.where(Character.enabled.is_(True))
    q = q.order_by(Character.kind.asc(), Character.id.asc())
    rows = (await db.execute(q)).scalars().all()
    return [_to_out(r) for r in rows]


@router.post("", response_model=CharacterOut)
async def create_character(
    body: CharacterCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CharacterOut:
    kind = normalize_kind(body.kind)
    if kind not in CLIENT_CREATABLE_KINDS:
        raise HTTPException(
            status_code=400,
            detail="Only person or toy characters can be created",
        )
    await _owned_child(db, user_id=user.id, child_id=body.related_child_id)
    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required")
    relation = (body.relation or "").strip() or None
    if kind != KIND_PERSON:
        relation = None
    note = (body.note or "").strip() or None
    row = Character(
        user_id=user.id,
        kind=kind,
        name=name,
        related_child_id=body.related_child_id,
        relation=relation,
        note=note,
        listener_child_id=None,
        enabled=True,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return _to_out(row)


@router.patch("/{character_id}", response_model=CharacterOut)
async def update_character(
    character_id: int,
    body: CharacterUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CharacterOut:
    row = await db.get(Character, character_id)
    if row is None or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Character not found")

    if body.related_child_id is not None:
        if row.kind == KIND_CHILD:
            raise HTTPException(
                status_code=400,
                detail="Cannot reassign a listener character",
            )
        await _owned_child(db, user_id=user.id, child_id=body.related_child_id)
        row.related_child_id = body.related_child_id

    if body.name is not None:
        name = body.name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="Name is required")
        row.name = name
        if row.kind == KIND_CHILD and row.listener_child_id is not None:
            child = await db.get(Child, row.listener_child_id)
            if child is not None and child.user_id == user.id:
                child.nickname = name

    if body.relation is not None:
        if row.kind == KIND_PERSON:
            row.relation = body.relation.strip() or None
        else:
            row.relation = None

    if body.note is not None:
        row.note = body.note.strip() or None

    if body.enabled is not None:
        if row.kind == KIND_CHILD and not body.enabled:
            raise HTTPException(
                status_code=400,
                detail="Cannot disable a listener character",
            )
        row.enabled = body.enabled

    await db.commit()
    await db.refresh(row)
    return _to_out(row)


@router.delete("/{character_id}")
async def delete_character(
    character_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    row = await db.get(Character, character_id)
    if row is None or row.user_id != user.id:
        raise HTTPException(status_code=404, detail="Character not found")
    if row.kind == KIND_CHILD:
        raise HTTPException(
            status_code=400,
            detail="Listener characters are removed with the child profile",
        )
    await db.delete(row)
    await db.commit()
    return {"ok": True, "id": character_id}
