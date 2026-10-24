"""Character roster helpers: ensure listener twin, load for stories."""

from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.character import Character
from app.models.child import Child

KIND_CHILD = "child"
KIND_PERSON = "person"
KIND_TOY = "toy"
ALLOWED_KINDS = frozenset({KIND_CHILD, KIND_PERSON, KIND_TOY})
CLIENT_CREATABLE_KINDS = frozenset({KIND_PERSON, KIND_TOY})
MAX_STORY_CHARACTERS = 8


def normalize_kind(raw: str | None) -> str:
    k = (raw or "").strip().lower()
    return k if k in ALLOWED_KINDS else ""


def roster_entry(row: Character, *, child: Child | None = None) -> dict:
    """Prompt roster item: name + optional desc/age/gender."""
    name = (row.name or "").strip() or "未命名"
    out: dict = {"name": name}
    rel = (row.relation or "").strip()
    note = (row.note or "").strip()
    desc_parts = [p for p in (rel, note) if p]
    if desc_parts:
        out["desc"] = "，".join(desc_parts)
    if child is not None:
        from app.services.child_profile import (
            GENDER_LABELS_ZH,
            age_years_int_on,
            normalize_gender,
        )

        age = age_years_int_on(child.birth_date)
        out["age"] = age
        gender = normalize_gender(child.gender)
        if gender and gender != "unspecified":
            out["gender"] = GENDER_LABELS_ZH.get(gender, gender)
    return out


def character_snapshot(row: Character, *, child: Child | None = None) -> dict:
    """Persist roster-ready fields so retry can rebuild without re-joining children."""
    entry = roster_entry(row, child=child)
    snap: dict = {
        "id": row.id,
        "kind": row.kind,
        "name": entry["name"],
        "related_child_id": row.related_child_id,
        "listener_child_id": row.listener_child_id,
    }
    if "desc" in entry:
        snap["desc"] = entry["desc"]
    if "age" in entry:
        snap["age"] = entry["age"]
    if "gender" in entry:
        snap["gender"] = entry["gender"]
    return snap


async def ensure_child_character(
    db: AsyncSession, *, user_id: int, child: Child
) -> Character:
    """Upsert the kind=child roster row for a listener."""
    existing = (
        await db.execute(
            select(Character).where(Character.listener_child_id == child.id)
        )
    ).scalar_one_or_none()
    name = (child.nickname or "").strip() or "未命名"
    if existing is not None:
        existing.name = name
        existing.related_child_id = child.id
        existing.user_id = user_id
        existing.kind = KIND_CHILD
        existing.enabled = True
        return existing
    row = Character(
        user_id=user_id,
        kind=KIND_CHILD,
        name=name,
        related_child_id=child.id,
        listener_child_id=child.id,
        relation=None,
        note=None,
        enabled=True,
    )
    db.add(row)
    await db.flush()
    return row


async def sync_child_character_name(
    db: AsyncSession, *, child_id: int, nickname: str
) -> None:
    row = (
        await db.execute(
            select(Character).where(Character.listener_child_id == child_id)
        )
    ).scalar_one_or_none()
    if row is None:
        return
    name = (nickname or "").strip() or "未命名"
    row.name = name


async def delete_characters_for_child(
    db: AsyncSession, *, user_id: int, child_id: int
) -> None:
    """Remove listener twin + person/toy owned by this child."""
    rows = (
        await db.execute(
            select(Character).where(
                Character.user_id == user_id,
                or_(
                    Character.listener_child_id == child_id,
                    Character.related_child_id == child_id,
                ),
            )
        )
    ).scalars().all()
    for row in rows:
        await db.delete(row)


async def load_characters_for_story(
    db: AsyncSession,
    *,
    user_id: int,
    character_ids: list[int],
    listener_child_id: int | None = None,
) -> list[Character]:
    """Validate ownership/enabled; order preserved, deduped.

    Characters may belong to any of the user's listeners (multi-audience nights).
    ``listener_child_id`` is accepted for call-site compatibility but no longer
    scopes the roster — selected ids are authoritative.
    """
    _ = listener_child_id
    if not character_ids:
        return []
    # Preserve order, drop dupes / over-limit.
    seen: set[int] = set()
    ordered: list[int] = []
    for cid in character_ids:
        if cid in seen:
            continue
        seen.add(cid)
        ordered.append(cid)
        if len(ordered) >= MAX_STORY_CHARACTERS:
            break
    rows = (
        await db.execute(
            select(Character).where(
                Character.user_id == user_id,
                Character.id.in_(ordered),
                Character.enabled.is_(True),
            )
        )
    ).scalars().all()
    by_id = {r.id: r for r in rows}
    missing = [i for i in ordered if i not in by_id]
    if missing:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="Character not found")
    return [by_id[i] for i in ordered]
