"""Story kernel catalog: general theme axes, soft recommend, usage dedup."""

from __future__ import annotations

import hashlib
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.story_kernel import StoryKernel, StoryKernelUsage
from app.services.child_profile import age_years_int_on
from app.services.element_age_stages import age_stage_for_years, stages_matching_years
from app.providers.story_prompt import FOCUS_POOLS, normalize_age_band

logger = logging.getLogger(__name__)

SOFT_DEDUP_DAYS = 30

KERNEL_USAGE_RULE = (
    "general thematic axis only; soft story gravity; "
    "never lecture, never moral punchline, never make this a classroom theme"
)

# focus_id → general axis (product vocabulary).
FOCUS_TO_AXIS: dict[str, str] = {
    "secure_presence": "security",
    "body_rhythm": "body",
    "name_feeling": "emotion",
    "tiny_brave": "courage",
    "emotion_held": "emotion",
    "gentle_agency": "self",
    "share_space": "belonging",
    "wind_down": "rest",
    "try_persist": "courage",
    "friend_repair": "belonging",
    "fair_turn": "fairness",
    "mentalize_light": "empathy",
    "curious_cause": "curiosity",
    "own_choice": "self",
}

AXIS_LABELS_ZH: dict[str, str] = {
    "security": "安全感",
    "body": "身体节奏",
    "emotion": "情绪感受",
    "courage": "勇气",
    "self": "自我与自主",
    "belonging": "归属与同伴",
    "rest": "安静与休息",
    "fairness": "公平",
    "empathy": "理解他人",
    "curiosity": "好奇",
}

# age_band → primary age_stage for chips / seeding
BAND_TO_STAGE: dict[str, str] = {
    "2-3": "toddler_2_3",
    "3-5": "preschool_3_5",
    "6-8": "early_school_6_8",
    "9-12": "late_school_9_12",
}


def age_stage_for_band(age_band: str | None) -> str:
    band = normalize_age_band(age_band)
    return BAND_TO_STAGE.get(band, "preschool_3_5")


def _seed_rows() -> list[dict[str, Any]]:
    """One kernel per (focus, age_band pool entry), mapped to age_stage."""
    rows: list[dict[str, Any]] = []
    sort = 0
    for band, pool in FOCUS_POOLS.items():
        stage = age_stage_for_band(band)
        for focus_id, how in pool:
            sort += 10
            axis = FOCUS_TO_AXIS.get(focus_id, "self")
            kid = f"{focus_id}_{stage}"
            name = (how.split("：")[0].split(":")[0].strip() or focus_id)[:128]
            guidance = (
                f"{how}。"
                "这是今晚故事的发展性引力轴，请轻触为愿望或关系走向；"
                "禁止点题说教、道德口号或课堂总结。"
            )
            rows.append(
                {
                    "id": kid,
                    "axis": axis,
                    "name": name,
                    "soft_guidance": guidance,
                    "age_stage": stage,
                    "focus_id": focus_id,
                    "enabled": True,
                    "sort_order": sort,
                }
            )
    return rows


async def upsert_canonical_kernels(db: AsyncSession) -> int:
    """Idempotent seed/update of canonical kernels from FOCUS_POOLS mapping."""
    n = 0
    for item in _seed_rows():
        row = await db.get(StoryKernel, item["id"])
        if row is None:
            db.add(StoryKernel(**item))
        else:
            row.axis = item["axis"]
            row.name = item["name"]
            row.soft_guidance = item["soft_guidance"]
            row.age_stage = item["age_stage"]
            row.focus_id = item["focus_id"]
            row.sort_order = item["sort_order"]
            # Do not force-enable if ops disabled a row.
        n += 1
    await db.commit()
    logger.info("canonical_kernels upserted count=%s", n)
    return n


async def seed_story_kernels_if_empty(db: AsyncSession) -> int:
    existing = (
        await db.execute(select(StoryKernel.id).limit(1))
    ).scalar_one_or_none()
    if existing is not None:
        # Still refresh canonical text for known ids.
        return await upsert_canonical_kernels(db)
    return await upsert_canonical_kernels(db)


def axis_for_focus(focus_id: str | None, *, axis_hint: str | None = None) -> tuple[str, str]:
    """Return (axis_id, axis_label_zh) for prompt-level soft gravity only."""
    fid = (focus_id or "").strip()
    axis = (axis_hint or "").strip() or FOCUS_TO_AXIS.get(fid, "self")
    if axis not in AXIS_LABELS_ZH and fid:
        axis = FOCUS_TO_AXIS.get(fid, axis or "self")
    if axis not in AXIS_LABELS_ZH:
        axis = "self"
    return axis, AXIS_LABELS_ZH[axis]


def kernel_to_prompt_payload(row: StoryKernel) -> dict[str, Any]:
    """Slim payload for inject — axis only (no name / soft_guidance)."""
    axis, label = axis_for_focus(row.focus_id, axis_hint=row.axis)
    return {
        "id": row.id,
        "axis": axis,
        "axis_label": label,
        "focus_id": row.focus_id,
        "usage_rule": KERNEL_USAGE_RULE,
    }


def kernel_to_chip(row: StoryKernel) -> dict[str, Any]:
    return {
        "id": row.id,
        "axis": row.axis,
        "axis_label": AXIS_LABELS_ZH.get(row.axis, row.axis),
        "name": row.name,
        "focus_id": row.focus_id,
        "age_stage": row.age_stage,
    }


async def list_kernels_for_band(
    db: AsyncSession, *, age_band: str | None, enabled_only: bool = True
) -> list[StoryKernel]:
    stage = age_stage_for_band(age_band)
    q = select(StoryKernel).where(StoryKernel.age_stage == stage)
    if enabled_only:
        q = q.where(StoryKernel.enabled.is_(True))
    q = q.order_by(StoryKernel.sort_order, StoryKernel.id)
    return list((await db.execute(q)).scalars().all())


async def suggest_kernels(
    db: AsyncSession,
    *,
    age_band: str | None,
    limit: int = 12,
    child_id: int | None = None,
    salt: str = "",
) -> list[dict[str, Any]]:
    """Sample kernels for inspiration chips: fresh preferred, stable shuffle."""
    rows = await list_kernels_for_band(db, age_band=age_band, enabled_only=True)
    if not rows:
        return []
    lim = max(1, min(int(limit or 12), 40))
    used: set[str] = set()
    if child_id is not None:
        used = await _recent_kernel_ids(db, child_id)
    fresh = [k for k in rows if k.id not in used]
    pool = fresh if fresh else list(rows)
    day = date.today().isoformat()
    band = normalize_age_band(age_band)
    pick_salt = f"suggest_k|{band}|{child_id or 0}|{day}|{salt}"
    ranked = sorted(
        pool,
        key=lambda k: hashlib.sha256(f"{pick_salt}|{k.id}".encode()).hexdigest(),
    )
    return [kernel_to_chip(k) for k in ranked[:lim]]


async def _recent_kernel_ids(
    db: AsyncSession, child_id: int, *, days: int = SOFT_DEDUP_DAYS
) -> set[str]:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = (
        await db.execute(
            select(StoryKernelUsage.kernel_id).where(
                and_(
                    StoryKernelUsage.child_id == child_id,
                    StoryKernelUsage.used_at >= since,
                )
            )
        )
    ).scalars().all()
    return {str(x) for x in rows}


def _stable_pick(candidates: list[StoryKernel], salt: str) -> StoryKernel:
    ranked = sorted(
        candidates,
        key=lambda e: hashlib.sha256(f"{salt}|{e.id}".encode()).hexdigest(),
    )
    return ranked[0]


async def get_kernel(db: AsyncSession, kernel_id: str) -> StoryKernel | None:
    return await db.get(StoryKernel, kernel_id)


async def find_kernel_by_focus(
    db: AsyncSession, *, focus_id: str, age_stage: str
) -> StoryKernel | None:
    return (
        await db.execute(
            select(StoryKernel).where(
                StoryKernel.focus_id == focus_id,
                StoryKernel.age_stage == age_stage,
                StoryKernel.enabled.is_(True),
            )
        )
    ).scalars().first()


async def select_story_kernel(
    db: AsyncSession,
    *,
    child_id: int,
    birth_date: date | None,
    salt: str,
    episode_no: int = 1,
    preferred: str | None = None,
    on: date | None = None,
) -> StoryKernel | None:
    """Pick one enabled kernel for child's stage; honor preferred id/focus_id."""
    age_years = age_years_int_on(birth_date, on=on)
    stages = stages_matching_years(age_years)
    if not stages:
        stages = [age_stage_for_years(age_years)]

    pref = (preferred or "").strip()
    if pref:
        by_id = await get_kernel(db, pref)
        if by_id is not None and by_id.enabled and by_id.age_stage in stages:
            return by_id
        # Prefer matching focus_id within stage(s)
        for st in stages:
            hit = await find_kernel_by_focus(db, focus_id=pref, age_stage=st)
            if hit is not None:
                return hit

    base = (
        await db.execute(
            select(StoryKernel).where(
                StoryKernel.enabled.is_(True),
                StoryKernel.age_stage.in_(stages),
            )
        )
    ).scalars().all()
    if not base:
        return None

    used = await _recent_kernel_ids(db, child_id)
    fresh = [k for k in base if k.id not in used]
    pool = fresh if fresh else list(base)
    # Include |used| so consecutive same-day standalone stories (episode_no=1)
    # reshuffle even if usage rows lag; soft-dedup still prefers unused ids.
    pick_salt = (
        f"kernel|{salt}|{on or date.today().isoformat()}|"
        f"{int(episode_no or 1)}|u{len(used)}"
    )
    return _stable_pick(pool, pick_salt)


async def record_kernel_usage(
    db: AsyncSession,
    *,
    child_id: int,
    kernel_id: str,
    story_id: int | None,
) -> None:
    db.add(
        StoryKernelUsage(
            child_id=child_id,
            kernel_id=kernel_id,
            story_id=story_id,
            used_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()


async def resolve_story_kernel_for_create(
    db: AsyncSession,
    *,
    child_id: int,
    birth_date: date | None,
    salt: str,
    episode_no: int,
    preferred: str | None,
    outline_focus: str | None,
    outline_how: str | None,
) -> tuple[str, str, str | None]:
    """Return (focus_id, axis_label_zh, kernel_id) for StoryRequest / params.

    Prompt inject uses axis only. soft_guidance / kernel name / outline_how
    stay out of development_focus_label (outline_how remains in series_context).
    """
    _ = outline_how  # series episode may still carry focus_how; not used as label
    if outline_focus:
        stage = age_stage_for_years(age_years_int_on(birth_date))
        k = await find_kernel_by_focus(db, focus_id=outline_focus, age_stage=stage)
        _axis, label = axis_for_focus(
            outline_focus, axis_hint=(k.axis if k else None)
        )
        return outline_focus, label, (k.id if k else None)

    row = await select_story_kernel(
        db,
        child_id=child_id,
        birth_date=birth_date,
        salt=salt,
        episode_no=episode_no,
        preferred=preferred,
    )
    if row is not None:
        _axis, label = axis_for_focus(row.focus_id, axis_hint=row.axis)
        return row.focus_id, label, row.id

    # Fallback to hardcoded pools — still only surface axis label.
    from app.providers.story_prompt import choose_development_focus
    from app.services.child_profile import sync_age_band

    band = sync_age_band(birth_date)
    fid, _pool_how = choose_development_focus(band, None, preferred=preferred, salt=salt)
    _axis, label = axis_for_focus(fid)
    return fid, label, None
