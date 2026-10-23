"""Reusable story roster: listener-linked child, people, and toys."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Character(Base):
    __tablename__ = "characters"
    __table_args__ = (
        UniqueConstraint("listener_child_id", name="uq_characters_listener_child"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    # child | person | toy
    kind: Mapped[str] = mapped_column(String(16), index=True)
    name: Mapped[str] = mapped_column(String(64))
    # Owning / related listener; required for person/toy; equals listener for kind=child.
    related_child_id: Mapped[int | None] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), nullable=True, index=True
    )
    # person only: 外公 / 同学 / …
    relation: Mapped[str | None] = mapped_column(String(64), nullable=True)
    # One-line trait / look (all kinds).
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    # kind=child only: 1:1 with children.id
    listener_child_id: Mapped[int | None] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), nullable=True, index=True
    )
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="characters")
