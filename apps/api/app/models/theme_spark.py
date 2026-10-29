"""Theme sparks: short one-line inspiration phrases for create-story hints."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class ThemeSpark(Base):
    """A short seed phrase shown as the create-page inspiration hint example."""

    __tablename__ = "theme_sparks"
    __table_args__ = (
        Index("ix_theme_sparks_lang_enabled_sort", "language", "enabled", "sort_order"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    # zh | en — zh covers Hans/Hant UI for short sparks.
    language: Mapped[str] = mapped_column(String(8), default="zh", index=True)
    text: Mapped[str] = mapped_column(String(64), default="")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
