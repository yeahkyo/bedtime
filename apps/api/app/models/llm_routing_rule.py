"""Admin-editable LLM routing rules (stage + match → llm_models row)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class LlmRoutingRule(Base):
    __tablename__ = "llm_routing_rules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    # Aligns with LlmAgent.id (e.g. story_draft).
    stage: Mapped[str] = mapped_column(String(64), index=True)
    # Lower runs first; first match wins.
    priority: Mapped[int] = mapped_column(Integer, default=100)
    # JSON object, e.g. {"duration_minutes_max": 5}. Empty / {} = catch-all.
    match_json: Mapped[str] = mapped_column(Text, default="{}")
    # Points at llm_models.id (provider + model_id + optional tier label).
    target_llm_model_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    label_zh: Mapped[str] = mapped_column(String(128), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
