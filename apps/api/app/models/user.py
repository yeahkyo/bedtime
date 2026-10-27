from datetime import datetime

from sqlalchemy import DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    apple_sub: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    token_version: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    disabled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    display_name: Mapped[str | None] = mapped_column(String(128), nullable=True)
    preferred_language: Mapped[str] = mapped_column(String(8), default="zh")
    story_retention_months: Mapped[int] = mapped_column(default=24)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_active_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    children = relationship("Child", back_populates="user", cascade="all, delete-orphan")
    characters = relationship(
        "Character", back_populates="user", cascade="all, delete-orphan"
    )
    # No delete-orphan: system catalog rows may have user_id cleared (promoted to global).
    voices = relationship(
        "Voice", back_populates="user", cascade="all", passive_deletes=True
    )
    stories = relationship("Story", back_populates="user", cascade="all, delete-orphan")
