from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class StorySeries(Base):
    """Soft multi-episode arc: outline once, then each night is one episode."""

    __tablename__ = "story_series"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    child_id: Mapped[int | None] = mapped_column(
        ForeignKey("children.id", ondelete="SET NULL"), nullable=True, index=True
    )
    title: Mapped[str] = mapped_column(String(256), default="")
    language: Mapped[str] = mapped_column(String(8), default="zh")
    theme: Mapped[str | None] = mapped_column(String(256), nullable=True)
    episode_count: Mapped[int] = mapped_column(Integer, default=4)
    outline_json: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String(32), default="active")  # active|completed
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User")
    child = relationship("Child")
