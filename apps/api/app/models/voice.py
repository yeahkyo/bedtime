from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base

# Shared system TTS voice display name (global catalog / system-default).
SYSTEM_VOICE_NAME = "枕边柔声"


class Voice(Base):
    __tablename__ = "voices"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    # NULL = global catalog (shared system presets). Set for per-user clones.
    user_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=True
    )
    name: Mapped[str] = mapped_column(String(64))
    # Short blurb for App picker (tone / character); admin-editable.
    description: Mapped[str | None] = mapped_column(String(200), nullable=True)
    kind: Mapped[str] = mapped_column(String(32), default="system")  # system | clone
    provider: Mapped[str] = mapped_column(String(32), default="fishaudio")
    provider_voice_id: Mapped[str] = mapped_column(String(128))
    # Optional per-voice TTS model (e.g. CosyVoice target_model). Empty → provider default.
    speech_model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    # Legacy tier label (slow|medium|fast); prefer numeric ``speed`` for TTS.
    speed_tier: Mapped[str] = mapped_column(String(16), default="medium")
    # Catalog default narration speed multiplier for all users (e.g. 0.85–1.2).
    speed: Mapped[float] = mapped_column(Float, default=1.0)
    # Disabled voices are hidden from the app catalog (admin can still edit).
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    # App picker order: lower first (admin-editable).
    sort_order: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    # Persisted TTS sample for admin/app preview playback.
    preview_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    preview_object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    preview_generated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    language: Mapped[str] = mapped_column(String(8), default="zh")
    consent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    raw_object_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    raw_purge_after: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="voices")


class VoicePrefs(Base):
    __tablename__ = "voice_prefs"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    child_id: Mapped[int] = mapped_column(ForeignKey("children.id", ondelete="CASCADE"), unique=True)
    speed_tier: Mapped[str] = mapped_column(String(16), default="medium")  # slow | medium | fast
    tone_preset: Mapped[str] = mapped_column(String(32), default="gentle")  # gentle | clear | lively
    likeness_boost: Mapped[bool] = mapped_column(Boolean, default=False)
    default_voice_id: Mapped[int | None] = mapped_column(ForeignKey("voices.id"), nullable=True)
    speed: Mapped[float] = mapped_column(Float, default=1.0)
    stability: Mapped[float] = mapped_column(Float, default=0.65)
    style: Mapped[float] = mapped_column(Float, default=0.05)
    similarity_boost: Mapped[float] = mapped_column(Float, default=0.75)

    child = relationship("Child", back_populates="voice_prefs")
