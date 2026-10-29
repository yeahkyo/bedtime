"""Per-user record of theme sparks consumed as create-page hints."""

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class UserThemeSparkUse(Base):
    __tablename__ = "user_theme_spark_uses"
    __table_args__ = (
        UniqueConstraint("user_id", "spark_id", name="uq_user_theme_spark_use"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    spark_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("theme_sparks.id", ondelete="CASCADE"), index=True
    )
    used_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
