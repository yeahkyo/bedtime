"""Story element catalog: seed taxonomy, recommend by age months, record usage."""

from __future__ import annotations

import hashlib
import logging
from datetime import date, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.story_element import (
    StoryElement,
    StoryElementCategory,
    StoryElementSubcategory,
    StoryElementUsage,
)
from app.services.child_profile import age_years_int_on
from app.services.element_age_stages import stages_matching_years

logger = logging.getLogger(__name__)

SOFT_DEDUP_DAYS = 30

ELEMENT_USAGE_RULE = (
    "objective knowledge only; soft sensory or setting detail; "
    "never lecture, never state a moral, never make this the story's theme"
)

# Canonical taxonomy: objective world slices (not SEL / morals / story themes).
SEED_CATEGORIES: list[dict[str, Any]] = [
    {
        "id": "nature_life",
        "label_zh": "自然与生命现象",
        "label_en": "Nature & Life",
        "sort_order": 10,
    },
    {
        "id": "matter_mechanics",
        "label_zh": "物性与日常机制",
        "label_en": "Matter & Mechanisms",
        "sort_order": 20,
    },
    {
        "id": "body_senses",
        "label_zh": "身体与可描述感受",
        "label_en": "Body & Observable Feelings",
        "sort_order": 30,
    },
    {
        "id": "time_space",
        "label_zh": "时间与空间的可观察变化",
        "label_en": "Time & Space Changes",
        "sort_order": 40,
    },
]

SEED_SUBCATEGORIES: list[dict[str, Any]] = [
    {
        "id": "plant_forms",
        "category_id": "nature_life",
        "label_zh": "植物形态与生长",
        "label_en": "Plant Forms",
        "id_prefix": "plg",
        "sort_order": 10,
        "generation_brief": (
            "可观察的植物事实：种子膨胀发芽、根向水伸展、叶面朝向光线、"
            "花朵开合、果实成熟变色、落叶与新芽。禁止寓意与人格化说教。"
        ),
    },
    {
        "id": "animal_habits",
        "category_id": "nature_life",
        "label_zh": "动物习性与生命周期",
        "label_en": "Animal Habits",
        "id_prefix": "ani",
        "sort_order": 20,
        "generation_brief": (
            "可观察的动物事实：蜕皮/变态、冬眠或迁徙、筑巢取材、保护色与躲藏、"
            "幼崽喂养与跟随。禁止「团结友爱」等价值口号。"
        ),
    },
    {
        "id": "weather_water",
        "category_id": "nature_life",
        "label_zh": "天气与水体",
        "label_en": "Weather & Water",
        "id_prefix": "wtr",
        "sort_order": 30,
        "generation_brief": (
            "云雨雪露雾的形态与转化、水面波纹与容积、泥土干湿、风向与强弱。"
            "只写可感知现象，不作象征解读。"
        ),
    },
    {
        "id": "light_color",
        "category_id": "matter_mechanics",
        "label_zh": "光影与色彩",
        "label_en": "Light & Color",
        "id_prefix": "ltc",
        "sort_order": 10,
        "generation_brief": (
            "影子随光源移动、水面反光、三棱镜/水珠分光、颜料叠色变深、透光与遮挡。"
            "只写可观察光学事实。"
        ),
    },
    {
        "id": "sound_wave",
        "category_id": "matter_mechanics",
        "label_zh": "声音与振动",
        "label_en": "Sound & Vibration",
        "id_prefix": "snd",
        "sort_order": 20,
        "generation_brief": (
            "物体振动发声、回声、隔墙/水下传声差异、音量与高低、安静时的环境底噪。"
            "只写可感知声学事实。"
        ),
    },
    {
        "id": "force_balance",
        "category_id": "matter_mechanics",
        "label_zh": "重力、浮力与平衡",
        "label_en": "Force & Balance",
        "id_prefix": "mch",
        "sort_order": 30,
        "generation_brief": (
            "落体、漂浮与沉底、跷跷板平衡、滑动与摩擦、弹簧回弹；"
            "可含轮子/杠杆等简单工具原理。禁止「努力就会成功」类隐喻。"
        ),
    },
    {
        "id": "daily_materials",
        "category_id": "matter_mechanics",
        "label_zh": "日常材料与食物由来",
        "label_en": "Materials & Food Origins",
        "id_prefix": "mat",
        "sort_order": 40,
        "generation_brief": (
            "常见材料触感与用途（布/木/金属/玻璃）、剪刀/锁/开关等简单结构、"
            "面粉来自谷物、牛奶来自奶畜、水烧开冒气。只写过程与来源，不写餐桌礼仪。"
        ),
    },
    {
        "id": "body_signals",
        "category_id": "body_senses",
        "label_zh": "身体信号",
        "label_en": "Body Signals",
        "id_prefix": "bdy",
        "sort_order": 10,
        "generation_brief": (
            "可描述的身体事实：心跳加快、肚子咕噜、哈欠、出汗、发抖、困倦眼皮变沉。"
            "说明「身体在发生什么」，不要教「应该怎样做」。"
        ),
    },
    {
        "id": "sense_channels",
        "category_id": "body_senses",
        "label_zh": "感官通道",
        "label_en": "Sense Channels",
        "id_prefix": "sns",
        "sort_order": 20,
        "generation_brief": (
            "触觉冷热粗细、嗅觉远近、味觉酸甜、视觉明暗、听觉方位。"
            "写成可核对的感官差异，不作性格评价。"
        ),
    },
    {
        "id": "feeling_body",
        "category_id": "body_senses",
        "label_zh": "感受的身体表现",
        "label_en": "Feelings in the Body",
        "id_prefix": "flb",
        "sort_order": 30,
        "generation_brief": (
            "常见感受在身体上的可观察表现：紧张时肩膀发紧、害怕时起鸡皮疙瘩、"
            "开心时嘴角上扬、悲伤时眼泪增多、放松时呼吸变慢。"
            "只描述现象，禁止道德评判与「要勇敢」类口号。"
        ),
    },
    {
        "id": "day_night_seasons",
        "category_id": "time_space",
        "label_zh": "昼夜与季节",
        "label_en": "Day, Night & Seasons",
        "id_prefix": "tim",
        "sort_order": 10,
        "generation_brief": (
            "天亮变亮、天黑变暗、影子长短变化、春芽夏叶秋果冬眠/落叶、年轮一圈一年。"
            "不作人生隐喻。"
        ),
    },
    {
        "id": "near_far_scale",
        "category_id": "time_space",
        "label_zh": "远近大小与视角",
        "label_en": "Scale & Perspective",
        "id_prefix": "spa",
        "sort_order": 20,
        "generation_brief": (
            "远处物体显得更小、站高看得更远、放大镜下的纹理、地图与实物比例。"
            "只写空间关系，不写人生哲理。"
        ),
    },
    {
        "id": "form_change",
        "category_id": "time_space",
        "label_zh": "物质形态变化",
        "label_en": "Form Changes",
        "id_prefix": "chg",
        "sort_order": 30,
        "generation_brief": (
            "冰融化成水、水结成冰、雪化湿衣、蜡滴凝固、蒸汽遇冷成水珠。"
            "写可逆/可观察的形态变化，禁止「告别与新生」等象征说法。"
        ),
    },
]


async def upsert_canonical_taxonomy(db: AsyncSession) -> dict[str, int]:
    """Idempotent sync of canonical categories/subcategories; prune obsolete rows (pre-prod)."""
    cats_upserted = 0
    subs_upserted = 0
    seed_cat_ids = {c["id"] for c in SEED_CATEGORIES}
    seed_sub_ids = {s["id"] for s in SEED_SUBCATEGORIES}

    for cat in SEED_CATEGORIES:
        row = await db.get(StoryElementCategory, cat["id"])
        if row is None:
            db.add(
                StoryElementCategory(
                    id=cat["id"],
                    label_zh=cat["label_zh"],
                    label_en=cat["label_en"],
                    sort_order=cat["sort_order"],
                    enabled=True,
                )
            )
        else:
            row.label_zh = cat["label_zh"]
            row.label_en = cat["label_en"]
            row.sort_order = cat["sort_order"]
            row.enabled = True
        cats_upserted += 1
    await db.flush()
    for sub in SEED_SUBCATEGORIES:
        row = await db.get(StoryElementSubcategory, sub["id"])
        if row is None:
            db.add(
                StoryElementSubcategory(
                    id=sub["id"],
                    category_id=sub["category_id"],
                    label_zh=sub["label_zh"],
                    label_en=sub["label_en"],
                    generation_brief=sub.get("generation_brief"),
                    id_prefix=sub.get("id_prefix"),
                    sort_order=sub["sort_order"],
                    enabled=True,
                )
            )
        else:
            row.category_id = sub["category_id"]
            row.label_zh = sub["label_zh"]
            row.label_en = sub["label_en"]
            row.generation_brief = sub.get("generation_brief")
            row.id_prefix = sub.get("id_prefix")
            row.sort_order = sub["sort_order"]
            row.enabled = True
        subs_upserted += 1
    await db.flush()

    # Drop elements under retired taxonomy, then prune obsolete sub/categories.
    obsolete_subs = (
        await db.execute(
            select(StoryElementSubcategory).where(
                StoryElementSubcategory.id.not_in(seed_sub_ids)
            )
        )
    ).scalars().all()
    pruned_subs = 0
    pruned_els = 0
    for sub in obsolete_subs:
        els = (
            await db.execute(
                select(StoryElement).where(StoryElement.subcategory_id == sub.id)
            )
        ).scalars().all()
        for el in els:
            await db.delete(el)
            pruned_els += 1
        await db.delete(sub)
        pruned_subs += 1

    obsolete_cats = (
        await db.execute(
            select(StoryElementCategory).where(
                StoryElementCategory.id.not_in(seed_cat_ids)
            )
        )
    ).scalars().all()
    pruned_cats = 0
    for cat in obsolete_cats:
        await db.delete(cat)
        pruned_cats += 1

    await db.commit()
    logger.info(
        "canonical_taxonomy upserted categories=%s subcategories=%s "
        "pruned_categories=%s pruned_subcategories=%s pruned_elements=%s",
        cats_upserted,
        subs_upserted,
        pruned_cats,
        pruned_subs,
        pruned_els,
    )
    return {
        "categories": cats_upserted,
        "subcategories": subs_upserted,
        "pruned_categories": pruned_cats,
        "pruned_subcategories": pruned_subs,
        "pruned_elements": pruned_els,
    }


def element_to_prompt_payload(
    row: StoryElement,
    *,
    category_label: str | None = None,
    subcategory_label: str | None = None,
) -> dict[str, Any]:
    cat = category_label
    sub = subcategory_label
    if cat is None and row.category is not None:
        cat = row.category.label_zh or row.category_id
    if sub is None and row.subcategory is not None:
        sub = row.subcategory.label_zh or row.subcategory_id
    return {
        "id": row.id,
        "name": row.name,
        "description": row.description,
        "category": cat or row.category_id,
        "subcategory": sub or row.subcategory_id,
        "usage_rule": ELEMENT_USAGE_RULE,
    }


async def seed_story_elements_if_empty(db: AsyncSession) -> int:
    """Ensure canonical taxonomy exists (idempotent). No sample elements."""
    await upsert_canonical_taxonomy(db)
    return 0


async def enable_elements_if_none_enabled(db: AsyncSession) -> int:
    """If catalog has rows but none enabled, enable all so silent recommend works.

    Admin generation historically inserted drafts as enabled=false; without a
    bulk-enable step, select_story_element always returned None.
    """
    total = (
        await db.execute(select(func.count()).select_from(StoryElement))
    ).scalar_one()
    if not total:
        return 0
    enabled_n = (
        await db.execute(
            select(func.count())
            .select_from(StoryElement)
            .where(StoryElement.enabled.is_(True))
        )
    ).scalar_one()
    if enabled_n:
        return 0
    rows = (await db.execute(select(StoryElement))).scalars().all()
    for row in rows:
        row.enabled = True
    await db.commit()
    logger.warning(
        "enabled %s draft story_elements (catalog had zero enabled)",
        len(rows),
    )
    return len(rows)


async def get_element_with_taxonomy(
    db: AsyncSession, element_id: str
) -> StoryElement | None:
    return (
        await db.execute(
            select(StoryElement)
            .where(StoryElement.id == element_id)
            .options(
                selectinload(StoryElement.category),
                selectinload(StoryElement.subcategory),
            )
        )
    ).scalar_one_or_none()


async def _recent_element_ids(
    db: AsyncSession, child_id: int, *, days: int = SOFT_DEDUP_DAYS
) -> set[str]:
    since = datetime.now(timezone.utc) - timedelta(days=days)
    rows = (
        await db.execute(
            select(StoryElementUsage.element_id).where(
                and_(
                    StoryElementUsage.child_id == child_id,
                    StoryElementUsage.used_at >= since,
                )
            )
        )
    ).scalars().all()
    return {str(x) for x in rows}


def _stable_pick(candidates: list[StoryElement], salt: str) -> StoryElement:
    ranked = sorted(
        candidates,
        key=lambda e: hashlib.sha256(f"{salt}|{e.id}".encode()).hexdigest(),
    )
    return ranked[0]


async def select_story_element(
    db: AsyncSession,
    *,
    child_id: int,
    birth_date: date | None,
    salt: str,
    episode_no: int = 1,
    on: date | None = None,
) -> StoryElement | None:
    """Pick one enabled element for the child's developmental stage; soft-dedup 30d."""
    age_years = age_years_int_on(birth_date, on=on)
    stages = stages_matching_years(age_years)
    if not stages:
        return None
    base = (
        await db.execute(
            select(StoryElement)
            .where(
                StoryElement.enabled.is_(True),
                StoryElement.age_stage.in_(stages),
            )
            .options(
                selectinload(StoryElement.category),
                selectinload(StoryElement.subcategory),
            )
        )
    ).scalars().all()
    if not base:
        disabled_n = (
            await db.execute(
                select(func.count())
                .select_from(StoryElement)
                .where(
                    StoryElement.enabled.is_(False),
                    StoryElement.age_stage.in_(stages),
                )
            )
        ).scalar_one()
        if disabled_n:
            logger.warning(
                "select_story_element empty: %s disabled drafts for stages=%s "
                "(enable in admin or wait for enable_elements_if_none_enabled)",
                disabled_n,
                stages,
            )
        return None

    used = await _recent_element_ids(db, child_id)
    fresh = [e for e in base if e.id not in used]
    pool = fresh if fresh else list(base)
    pick_salt = f"{salt}|{on or date.today().isoformat()}|{int(episode_no or 1)}"
    return _stable_pick(pool, pick_salt)


async def record_element_usage(
    db: AsyncSession,
    *,
    child_id: int,
    element_id: str,
    story_id: int | None,
) -> None:
    db.add(
        StoryElementUsage(
            child_id=child_id,
            element_id=element_id,
            story_id=story_id,
            used_at=datetime.now(timezone.utc),
        )
    )
    await db.commit()


async def _usage_exists_for_story(
    db: AsyncSession, *, story_id: int, element_id: str
) -> bool:
    row = (
        await db.execute(
            select(StoryElementUsage.id).where(
                StoryElementUsage.story_id == story_id,
                StoryElementUsage.element_id == element_id,
            ).limit(1)
        )
    ).scalar_one_or_none()
    return row is not None


async def resolve_story_element_for_job(
    db: AsyncSession,
    *,
    child_id: int,
    birth_date: date | None,
    salt: str,
    episode_no: int,
    story_id: int,
    reuse_element_id: str | None,
) -> dict[str, Any] | None:
    """Load reused element or select + record usage; return prompt payload."""
    row: StoryElement | None = None
    if reuse_element_id:
        row = await get_element_with_taxonomy(db, reuse_element_id)
    if row is None:
        row = await select_story_element(
            db,
            child_id=child_id,
            birth_date=birth_date,
            salt=salt,
            episode_no=episode_no,
        )
        if row is None:
            return None
        await record_element_usage(
            db, child_id=child_id, element_id=row.id, story_id=story_id
        )
    elif not await _usage_exists_for_story(
        db, story_id=story_id, element_id=row.id
    ):
        # User-picked chip or first resolve for this story.
        await record_element_usage(
            db, child_id=child_id, element_id=row.id, story_id=story_id
        )
    return element_to_prompt_payload(row)


def _stable_rank(ids_and_items: list[tuple[str, Any]], salt: str) -> list[Any]:
    ranked = sorted(
        ids_and_items,
        key=lambda pair: hashlib.sha256(f"{salt}|{pair[0]}".encode()).hexdigest(),
    )
    return [item for _, item in ranked]


async def suggest_elements(
    db: AsyncSession,
    *,
    age_band: str,
    limit: int = 12,
    child_id: int | None = None,
    salt: str = "",
) -> list[dict[str, Any]]:
    """Sample enabled elements for chips: fresh (30d) preferred, stable shuffle."""
    from app.providers.story_prompt import normalize_age_band
    from app.services.story_kernels import age_stage_for_band

    band = normalize_age_band(age_band)
    stage = age_stage_for_band(band)
    lim = max(1, min(int(limit or 12), 40))
    rows = list(
        (
            await db.execute(
                select(StoryElement)
                .where(
                    StoryElement.enabled.is_(True),
                    StoryElement.age_stage == stage,
                )
                .options(selectinload(StoryElement.subcategory))
            )
        )
        .scalars()
        .all()
    )
    if not rows:
        return []

    used: set[str] = set()
    if child_id is not None:
        used = await _recent_element_ids(db, child_id)
    fresh = [e for e in rows if e.id not in used]
    pool = fresh if fresh else list(rows)
    day = date.today().isoformat()
    pick_salt = f"suggest_el|{band}|{child_id or 0}|{day}|{salt}"
    ranked = _stable_rank([(e.id, e) for e in pool], pick_salt)
    out: list[dict[str, Any]] = []
    for e in ranked[:lim]:
        sub = ""
        if e.subcategory is not None:
            sub = e.subcategory.label_zh or e.subcategory_id
        out.append(
            {
                "id": e.id,
                "name": e.name,
                "subcategory": sub or e.subcategory_id,
                "age_stage": e.age_stage,
            }
        )
    return out
