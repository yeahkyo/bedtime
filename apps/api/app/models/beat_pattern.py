"""Admin-editable bedtime rhythm frames (fairy/fable/drama beats)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class StoryBeatPattern(Base):
    __tablename__ = "story_beat_patterns"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    label: Mapped[str] = mapped_column(String(128), default="")
    lineage: Mapped[str] = mapped_column(String(32), default="")
    theme_tags_json: Mapped[str] = mapped_column(Text, default="[]")
    slots: Mapped[str] = mapped_column(String(256), default="wish, snag, try_1, try_2, turn_ok")
    instruction: Mapped[str] = mapped_column(Text, default="")
    escalation: Mapped[str | None] = mapped_column(Text, nullable=True)
    focus_ids_json: Mapped[str] = mapped_column(Text, default="[]")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
