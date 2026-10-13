"""Phase 2 photo-memory hooks — tables exist so MVP migrations don't block later work."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Memory(Base):
    __tablename__ = "memories"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    child_id: Mapped[int | None] = mapped_column(ForeignKey("children.id", ondelete="SET NULL"), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    captured_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MemoryAsset(Base):
    __tablename__ = "memory_assets"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    memory_id: Mapped[int] = mapped_column(ForeignKey("memories.id", ondelete="CASCADE"), index=True)
    object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)  # null if local-only
    local_only: Mapped[int] = mapped_column(Integer, default=1)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MemoryElement(Base):
    __tablename__ = "memory_elements"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    memory_id: Mapped[int] = mapped_column(ForeignKey("memories.id", ondelete="CASCADE"), index=True)
    elements_json: Mapped[str] = mapped_column(Text, default="{}")
    model_version: Mapped[str | None] = mapped_column(String(64), nullable=True)
    confirmed: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
