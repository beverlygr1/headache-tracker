from datetime import datetime

from sqlalchemy import ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.types import UTCDateTime


class Attack(TimestampMixin, Base):
    __tablename__ = "attacks"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    start_time: Mapped[datetime] = mapped_column(UTCDateTime(), index=True, nullable=False)
    end_time: Mapped[datetime | None] = mapped_column(UTCDateTime(), nullable=True)
    intensity: Mapped[int] = mapped_column(Integer, nullable=False)
    pain_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    localization: Mapped[str | None] = mapped_column(String(120), nullable=True)
    medications: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    symptoms: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    relief_factors: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)

    user = relationship("User", back_populates="attacks")
