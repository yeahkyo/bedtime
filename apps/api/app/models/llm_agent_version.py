"""Immutable prompt history for llm_agents (system/user + generation knobs)."""

from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class LlmAgentVersion(Base):
    __tablename__ = "llm_agent_versions"
    __table_args__ = (
        UniqueConstraint("agent_id", "version", name="uq_llm_agent_versions_agent_version"),
        Index("ix_llm_agent_versions_agent_created", "agent_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    agent_id: Mapped[str] = mapped_column(
        String(64),
        ForeignKey("llm_agents.id", ondelete="CASCADE"),
        index=True,
    )
    version: Mapped[int] = mapped_column(Integer, nullable=False)
    note: Mapped[str] = mapped_column(String(256), default="")
    system_prompt: Mapped[str] = mapped_column(Text, default="")
    user_prompt_template: Mapped[str] = mapped_column(Text, default="{{user_payload}}")
    temperature: Mapped[float | None] = mapped_column(Float, nullable=True)
    max_tokens: Mapped[int | None] = mapped_column(Integer, nullable=True)
    timeout_seconds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # admin_save | lab_save | restore | reset_code
    source: Mapped[str] = mapped_column(String(32), default="admin_save")
    created_by: Mapped[str] = mapped_column(String(128), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
