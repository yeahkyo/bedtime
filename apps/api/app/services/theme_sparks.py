"""Theme spark catalog: seed defaults + list helpers for create-page hints."""

from __future__ import annotations

import logging

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.theme_spark import ThemeSpark

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
