from datetime import datetime
from sqlalchemy import ForeignKey, String, Integer, Float, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UserMedication(Base):
    """Таблица аптечки пользователя"""
    __tablename__ = "user_medications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    dosage: Mapped[str] = mapped_column(String(50), nullable=False)
    usage_count: Mapped[int] = mapped_column(Integer, default=0)
    effectiveness_pct: Mapped[float] = mapped_column(Float, default=0.0)


class UserSetting(Base):
    """Настройки уведомлений и интерфейса"""
    __tablename__ = "user_settings"

    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    work_schedule: Mapped[str] = mapped_column(String(32), default="5/2")
    daily_reminder_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    daily_reminder_time: Mapped[str] = mapped_column(String(5), default="20:00")
    risk_alert_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    medication_reminder_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    medication_reminder_time: Mapped[str] = mapped_column(String(5), default="08:00")
    theme: Mapped[str] = mapped_column(String(16), default="dark")


class UserSupplement(Base):
    """Профилактика и витамины"""
    __tablename__ = "user_supplements"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    intake_time: Mapped[str] = mapped_column(String(5), nullable=False)