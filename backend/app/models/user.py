from datetime import date

from sqlalchemy import Boolean, CheckConstraint, Date, Integer, String, false, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin


class User(TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "onboarding_step BETWEEN 0 AND 1", name="ck_users_onboarding_step"
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(
        String(320), unique=True, index=True, nullable=False
    )
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    time_zone: Mapped[str | None] = mapped_column(String(64), nullable=True)
    gender: Mapped[str | None] = mapped_column(String(32), nullable=True)
    birth_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    onboarding_step: Mapped[int] = mapped_column(
        Integer, default=0, server_default=text("0"), nullable=False
    )
    onboarding_completed: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=false(), nullable=False
    )

    attacks = relationship(
        "Attack", back_populates="user", cascade="all, delete-orphan"
    )
    diary_entries = relationship(
        "DiaryEntry", back_populates="user", cascade="all, delete-orphan"
    )
