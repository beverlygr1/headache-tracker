from datetime import datetime

from sqlalchemy import Float, ForeignKey, SmallInteger, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base
from app.models.types import UTCDateTime


class Prediction(Base):
    __tablename__ = "predictions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        UTCDateTime(), server_default=func.now(), nullable=False
    )
    stress: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    excess_sleep: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    lack_of_sleep: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    exercise_trigger: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    no_exercise_trigger: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    physical_fatigue: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    menstrual_phase: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    ovulation_phase: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    excessive_emotional_change: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    weather_change: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    excessive_sunlight: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    noise: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    poor_lighting: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    specific_smell: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    excessive_alcohol: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    irregular_meals: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    overeating: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    excessive_caffeine: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    excessive_smoking: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    cheese_chocolate: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    travel: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    other_trigger: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    days_since_last_attack: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    attacks_last_7_records: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    weather_observation_id: Mapped[int | None] = mapped_column(
        ForeignKey("weather_observations.id", ondelete="SET NULL"), nullable=True
    )
    probability: Mapped[float] = mapped_column(Float, nullable=False)
