from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.mysql import MEDIUMTEXT
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Story(Base):
    __tablename__ = "stories"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    child_id: Mapped[int | None] = mapped_column(ForeignKey("children.id", ondelete="SET NULL"), nullable=True)
    voice_id: Mapped[int | None] = mapped_column(ForeignKey("voices.id", ondelete="SET NULL"), nullable=True)

    title: Mapped[str] = mapped_column(String(256), default="")
    language: Mapped[str] = mapped_column(String(8), default="zh")
    theme: Mapped[str | None] = mapped_column(String(256), nullable=True)
    body: Mapped[str] = mapped_column(Text, default="")
    status: Mapped[str] = mapped_column(String(32), default="draft")  # draft|generating|ready|failed
    # queued|series_outline|episode_plan|draft|tts|ready|failed
    progress: Mapped[str | None] = mapped_column(String(32), nullable=True)
    # Last time status/progress changed (orphan reclaim / stuck detection).
    progress_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, default=5)

    # MVP hooks for Phase 2 photo memories + soft series
    source: Mapped[str] = mapped_column(String(32), default="manual")  # manual | memory
    params_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    memory_ids_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Links to story_series.id (no DB FK for easier create_all on existing DBs)
    series_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    episode_no: Mapped[int | None] = mapped_column(Integer, nullable=True)
    recap: Mapped[str | None] = mapped_column(Text, nullable=True)
    soft_hook: Mapped[str | None] = mapped_column(Text, nullable=True)
    voice_settings_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Job-level story provider snapshot (fallback / legacy). Prefer metrics_json stages.
    story_provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    # Snapshot of resolved draft LLM model (list/filter); metrics_json is source of truth.
    story_model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    speech_provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    # Snapshot of Voice.speech_model (or resolved default) at generation time.
    speech_model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    # LLM episode_plan JSON (admin quality tooling); null for older rows / failures before plan.
    episode_plan_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Generation timing + token usage JSON for admin detail (null for older rows).
    metrics_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Submitted system+user text per LLM stage (admin detail). MEDIUMTEXT: prompts exceed TEXT.
    prompts_json: Mapped[str | None] = mapped_column(
        Text().with_variant(MEDIUMTEXT(), "mysql"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user = relationship("User", back_populates="stories")
    audio = relationship("StoryAudio", back_populates="story", uselist=False, cascade="all, delete-orphan")


class StoryAudio(Base):
    __tablename__ = "story_audio"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    story_id: Mapped[int] = mapped_column(ForeignKey("stories.id", ondelete="CASCADE"), unique=True)
    object_key: Mapped[str] = mapped_column(String(512))
    content_type: Mapped[str] = mapped_column(String(64), default="audio/mpeg")
    duration_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    story = relationship("Story", back_populates="audio")
