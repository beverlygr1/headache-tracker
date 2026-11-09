from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, Float, JSON, SmallInteger, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base
from app.models.types import UTCDateTime


class WeatherObservation(Base):
    __tablename__ = "weather_observations"
    __table_args__ = (
        CheckConstraint("pressure_level BETWEEN 0 AND 2", name="ck_weather_pressure_level"),
        CheckConstraint("temperature_level BETWEEN 0 AND 2", name="ck_weather_temperature_level"),
        CheckConstraint("weather_change_level BETWEEN 0 AND 2", name="ck_weather_change_level"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    local_date: Mapped[date] = mapped_column(Date, nullable=False)
    timezone: Mapped[str] = mapped_column(String(64), nullable=False)
    source: Mapped[str] = mapped_column(String(32), nullable=False)
    fetched_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.now(), nullable=False
    )
    mean_pressure_msl_today: Mapped[float] = mapped_column(Float, nullable=False)
    mean_pressure_msl_prev: Mapped[float] = mapped_column(Float, nullable=False)
    mean_temperature_today: Mapped[float] = mapped_column(Float, nullable=False)
    mean_temperature_prev: Mapped[float] = mapped_column(Float, nullable=False)
    delta_pressure_hpa: Mapped[float] = mapped_column(Float, nullable=False)
    delta_temperature_c: Mapped[float] = mapped_column(Float, nullable=False)
    pressure_level: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    temperature_level: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    weather_change_level: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    raw_hourly: Mapped[dict] = mapped_column(JSON, nullable=False)
