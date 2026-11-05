from datetime import datetime

from sqlalchemy import ForeignKey, Integer, JSON, String, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.types import UTCDateTime


class Attack(TimestampMixin, Base):
    __tablename__ = "attacks"
    __table_args__ = (UniqueConstraint("user_id", "client_request_id", name="uq_attack_client_request"),)

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
    medication_effects: Mapped[dict[str, str]] = mapped_column(JSON, default=dict, server_default=text("'{}'"), nullable=False)
    client_request_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    client_payload_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)

    user = relationship("User", back_populates="attacks")
