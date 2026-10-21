"""Configurable LLM agent roles (prompts + optional provider/model)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class LlmAgent(Base):
    __tablename__ = "llm_agents"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    label_zh: Mapped[str] = mapped_column(String(128), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    # Empty → use runtime/global story provider (story agents) or caller override (catalog).
    provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    system_prompt: Mapped[str] = mapped_column(Text, default="")
    user_prompt_template: Mapped[str] = mapped_column(Text, default="{{user_payload}}")
    max_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    timeout_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Null → runtime default (0.7).
    temperature: Mapped[float | None] = mapped_column(Float, nullable=True)
    # JSON list: [{"name":"user_payload","description":"..."}]
    placeholders_json: Mapped[str] = mapped_column(Text, default="[]")
    # False → runtime always uses code fallback (safety).
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
