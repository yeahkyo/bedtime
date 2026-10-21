"""Story kernel catalog: general developmental theme axes (not plot seeds)."""

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class StoryKernel(Base):
    """General thematic axis for tonight's story gravity — not a moral slogan or plot."""

    __tablename__ = "story_kernels"
    __table_args__ = (
        Index("ix_story_kernels_enabled_stage", "enabled", "age_stage"),
        Index("ix_story_kernels_axis_stage", "axis", "age_stage"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    # General axis: courage | self | belonging | curiosity | security | …
    axis: Mapped[str] = mapped_column(String(32), default="", index=True)
    name: Mapped[str] = mapped_column(String(128), default="")
    # Soft how-to for plan: lightly weave; never lecture or moral punchline.
    soft_guidance: Mapped[str] = mapped_column(Text, default="")
    age_stage: Mapped[str] = mapped_column(String(32), default="preschool_3_5", index=True)
    # Maps into FOCUS_POOLS / development_focus ids.
    focus_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class StoryKernelUsage(Base):
    __tablename__ = "story_kernel_usages"
    __table_args__ = (Index("ix_story_kernel_usages_child_used", "child_id", "used_at"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    child_id: Mapped[int] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), index=True
    )
    kernel_id: Mapped[str] = mapped_column(
        ForeignKey("story_kernels.id", ondelete="CASCADE"), index=True
    )
    story_id: Mapped[int | None] = mapped_column(
        ForeignKey("stories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    used_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )
