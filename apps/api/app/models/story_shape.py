"""Admin-editable story architecture shapes (story_shape pool)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class StoryShape(Base):
    __tablename__ = "story_shapes"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    label_zh: Mapped[str] = mapped_column(String(128), default="")
    guidance: Mapped[str] = mapped_column(Text, default="")
    effect: Mapped[str] = mapped_column(Text, default="")
    beat_min: Mapped[int] = mapped_column(Integer, default=2)
    beat_max: Mapped[int] = mapped_column(Integer, default=6)
    example_beats_json: Mapped[str] = mapped_column(Text, default="[]")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
