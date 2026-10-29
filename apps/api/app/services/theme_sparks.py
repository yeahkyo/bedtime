"""Theme spark catalog: seed defaults + list helpers for create-page hints."""

from __future__ import annotations

import logging

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.theme_spark import ThemeSpark
from app.models.user_theme_spark_use import UserThemeSparkUse

logger = logging.getLogger(__name__)

# Built-in pool (also used as client offline fallback). Theme/mood — not plot synopses.
DEFAULT_SPARKS: dict[str, list[str]] = {
    "zh": [
        "我不想睡觉",
        "勇气与月亮",
        "小小和好",
        "今天有点委屈",
        "想变成一朵云",
        "雨声和好朋友",
        "第一次说对不起",
        "被轻轻抱抱",
    ],
    "en": [
        "I don't want to sleep",
        "courage and moonlight",
        "a tiny make-up",
        "a little sad today",
        "want to be a cloud",
        "rain and a friend",
        "saying sorry first",
        "a soft hug",
    ],
}


def normalize_spark_language(raw: str | None) -> str:
    lang = (raw or "zh").strip().lower().replace("-", "_")
    if lang.startswith("en"):
        return "en"
    return "zh"


async def seed_theme_sparks_if_empty(db: AsyncSession) -> int:
    """Insert code defaults when the table has no rows."""
    count = int((await db.execute(select(func.count()).select_from(ThemeSpark))).scalar_one())
    if count > 0:
        return 0
    n = 0
    for language, texts in DEFAULT_SPARKS.items():
        for i, text in enumerate(texts):
            db.add(
                ThemeSpark(
                    language=language,
                    text=text,
                    enabled=True,
                    sort_order=(i + 1) * 10,
                )
            )
            n += 1
    await db.commit()
    logger.info("theme_sparks seeded count=%s", n)
    return n


async def list_enabled_sparks(
    db: AsyncSession, *, language: str
) -> list[ThemeSpark]:
    lang = normalize_spark_language(language)
    rows = (
        await db.execute(
            select(ThemeSpark)
            .where(ThemeSpark.language == lang, ThemeSpark.enabled.is_(True))
            .order_by(ThemeSpark.sort_order, ThemeSpark.id)
        )
    ).scalars().all()
    return list(rows)


async def list_enabled_sparks_for_user(
    db: AsyncSession, *, language: str, user_id: int
) -> list[ThemeSpark]:
    """Enabled sparks for [language], omitting ones this user already used as hints.

    If every spark was used, return the full enabled list so the client can rotate again.
    """
    all_rows = await list_enabled_sparks(db, language=language)
    if not all_rows:
        return []
    used_ids = set(
        (
            await db.execute(
                select(UserThemeSparkUse.spark_id).where(
                    UserThemeSparkUse.user_id == user_id
                )
            )
        )
        .scalars()
        .all()
    )
    if not used_ids:
        return all_rows
    remaining = [r for r in all_rows if r.id not in used_ids]
    return remaining if remaining else all_rows


async def resolve_spark_id_for_hint(
    db: AsyncSession, *, spark_id: int | None, theme: str | None, language: str
) -> int | None:
    """Prefer explicit id; else match enabled spark text for language."""
    if spark_id is not None and spark_id >= 1:
        row = await db.get(ThemeSpark, spark_id)
        if row is not None and row.enabled:
            return int(row.id)
    text = (theme or "").strip()
    if not text:
        return None
    lang = normalize_spark_language(language)
    found = (
        await db.execute(
            select(ThemeSpark.id)
            .where(
                ThemeSpark.language == lang,
                ThemeSpark.enabled.is_(True),
                ThemeSpark.text == text,
            )
            .limit(1)
        )
    ).scalar_one_or_none()
    return int(found) if found is not None else None


async def record_theme_spark_hint_use(
    db: AsyncSession,
    *,
    user_id: int,
    spark_id: int | None = None,
    theme: str | None = None,
    language: str = "zh",
) -> None:
    """Idempotently mark a spark as used for hint-sourced creates. Caller commits."""
    resolved = await resolve_spark_id_for_hint(
        db, spark_id=spark_id, theme=theme, language=language
    )
    if resolved is None:
        return
    exists = (
        await db.execute(
            select(UserThemeSparkUse.id).where(
                UserThemeSparkUse.user_id == user_id,
                UserThemeSparkUse.spark_id == resolved,
            )
        )
    ).scalar_one_or_none()
    if exists is not None:
        return
    db.add(UserThemeSparkUse(user_id=user_id, spark_id=resolved))
