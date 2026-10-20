import logging
import math
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.ml.features import DiaryValues, build_features
from app.ml.prediction_schemas import PredictionInput
from app.ml.predictor import load_model
from app.models.types import ensure_utc
from app.models.user import User
from app.repositories import attacks as attacks_repo
from app.repositories import diary as diary_repo
from app.schemas.forecast import ForecastInputField, RiskForecastResponse

logger = logging.getLogger(__name__)
REQUIRED_FIELDS: tuple[ForecastInputField, ...] = (
    "sleep_hours",
    "stress_level",
    "caffeine_intake",
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _user_tz(user: User):
    if user.time_zone:
        try:
            return ZoneInfo(user.time_zone)
        except (ZoneInfoNotFoundError, ValueError):
            pass
    return timezone.utc


def _local_date(moment: datetime, tz) -> date:
    return ensure_utc(moment).astimezone(tz).date()


def get_forecast(
    db: Session, user: User, now: datetime | None = None
) -> RiskForecastResponse:
    calculated_at = ensure_utc(now if now is not None else _now())
    tz = _user_tz(user)
    today = calculated_at.astimezone(tz).date()
    metadata = {
        "calculated_at": calculated_at,
        "prediction_date": today + timedelta(days=1),
        "time_zone": getattr(tz, "key", "UTC"),
    }
    # A technical input requirement, not a claim of validated model accuracy.
    today_entry = diary_repo.get_entry(db, user.id, today)
    missing = [
        field
        for field in REQUIRED_FIELDS
        if today_entry is None or getattr(today_entry, field) is None
    ]
    if missing:
        return RiskForecastResponse(
            status="insufficient_data",
            **metadata,
            missing_fields=missing,
            message="Для расчёта заполните сегодняшние значения сна, стресса и кофеина.",
        )

    entries = [
        DiaryValues(
            date=e.date,
            sleep_hours=e.sleep_hours,
            stress_level=e.stress_level,
            caffeine_intake=e.caffeine_intake,
        )
        for e in diary_repo.list_entries(db, user.id, None, today)
    ]
    # Do not feed attacks scheduled later today (or in future days) into history.
    attack_dates = [
        _local_date(start, tz)
        for start in attacks_repo.list_start_times(db, user.id, until=calculated_at)
    ]
    features = build_features(entries, attack_dates, today)
    try:
        probability = load_model().predict(PredictionInput(**features))
        if not math.isfinite(probability) or not 0 <= probability <= 1:
            raise ValueError("Model returned an invalid probability")
    except Exception as exc:
        logger.exception("Forecast model could not produce a probability")
        raise HTTPException(
            status_code=503,
            detail="Прогноз временно недоступен. Повторите запрос позже.",
        ) from exc
    return RiskForecastResponse(
        status="ready",
        **metadata,
        risk_level=str(round(probability * 100)),
        probability=probability,
    )
