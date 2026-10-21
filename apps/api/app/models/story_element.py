"""Story element catalog: taxonomy + objective developmental knowledge + usage."""

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
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class StoryElementCategory(Base):
    __tablename__ = "story_element_categories"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    label_zh: Mapped[str] = mapped_column(String(128), default="")
    label_en: Mapped[str] = mapped_column(String(128), default="")
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    subcategories = relationship(
        "StoryElementSubcategory", back_populates="category", cascade="all, delete-orphan"
    )


class StoryElementSubcategory(Base):
    __tablename__ = "story_element_subcategories"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    category_id: Mapped[str] = mapped_column(
        ForeignKey("story_element_categories.id", ondelete="CASCADE"), index=True
    )
    label_zh: Mapped[str] = mapped_column(String(128), default="")
    label_en: Mapped[str] = mapped_column(String(128), default="")
    generation_brief: Mapped[str | None] = mapped_column(Text, nullable=True)
    id_prefix: Mapped[str | None] = mapped_column(String(16), nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    category = relationship("StoryElementCategory", back_populates="subcategories")


class StoryElement(Base):
    """Objective knowledge entry — not story morals or plot seeds."""

    __tablename__ = "story_elements"
    __table_args__ = (
        Index("ix_story_elements_enabled_category", "enabled", "category_id"),
        Index("ix_story_elements_age_stage", "age_stage", "enabled"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    category_id: Mapped[str] = mapped_column(
        ForeignKey("story_element_categories.id", ondelete="RESTRICT"), index=True
    )
    subcategory_id: Mapped[str] = mapped_column(
        ForeignKey("story_element_subcategories.id", ondelete="RESTRICT"), index=True
    )
    # Objective name of the phenomenon / thing (not a story title).
    name: Mapped[str] = mapped_column(String(256), default="")
    # Neutral developmental / encyclopedic description.
    description: Mapped[str] = mapped_column(Text, default="")
    # Developmental stage id: toddler_2_3 | preschool_3_5 | early_school_6_8 | late_school_9_12
    age_stage: Mapped[str] = mapped_column(String(32), default="preschool_3_5", index=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    category = relationship("StoryElementCategory")
    subcategory = relationship("StoryElementSubcategory")


class StoryElementUsage(Base):
    __tablename__ = "story_element_usages"
    __table_args__ = (Index("ix_story_element_usages_child_used", "child_id", "used_at"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    child_id: Mapped[int] = mapped_column(
        ForeignKey("children.id", ondelete="CASCADE"), index=True
    )
    element_id: Mapped[str] = mapped_column(
        ForeignKey("story_elements.id", ondelete="CASCADE"), index=True
    )
    story_id: Mapped[int | None] = mapped_column(
        ForeignKey("stories.id", ondelete="SET NULL"), nullable=True, index=True
    )
    used_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )
