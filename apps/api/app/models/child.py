from datetime import date, datetime

from sqlalchemy import Date, DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Child(Base):
    __tablename__ = "children"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    nickname: Mapped[str] = mapped_column(String(64))
    # Kept in sync from birth_date for prompt routing / legacy clients.
    age_band: Mapped[str] = mapped_column(String(32), default="3-5")  # 2-3 | 3-5 | 6-8
    birth_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    gender: Mapped[str] = mapped_column(String(32), default="unspecified")  # girl|boy|other|unspecified
    intro: Mapped[str | None] = mapped_column(Text, nullable=True)  # free-text intro for storytelling
    interests_json: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON array
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="children")
    voice_prefs = relationship(
        "VoicePrefs", back_populates="child", uselist=False, cascade="all, delete-orphan"
    )
