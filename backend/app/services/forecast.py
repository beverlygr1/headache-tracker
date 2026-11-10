import logging
import math
from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.ml.features import DiaryValues, build_features
from app.ml.prediction_schemas import PredictionInput
from app.ml.predictor import load_model
from app.models.diary import DiaryEntry
from app.models.types import ensure_utc
from app.models.user import User
from app.models.weather_observation import WeatherObservation
from app.repositories import attacks as attacks_repo
from app.repositories import diary as diary_repo
from app.repositories import predictions as predictions_repo
from app.schemas.forecast import ForecastInputField, RiskForecastResponse
from app.services.weather import (
    WeatherUnavailableError,
    get_weather_change,
    to_response,
)

logger = logging.getLogger(__name__)
REQUIRED_FIELDS: tuple[ForecastInputField, ...] = (
    "sleep_hours",
    "stress_level",
    "caffeine_intake",
)


def _now() -> datetime:
    return datetime.now(UTC)


def _user_tz(user: User):
    if user.time_zone:
        try:
            return ZoneInfo(user.time_zone)
        except (ZoneInfoNotFoundError, ValueError):
            pass
    return UTC


def _local_date(moment: datetime, tz) -> date:
    return ensure_utc(moment).astimezone(tz).date()


def _coordinates(
    latitude: float | None,
    longitude: float | None,
    entry: DiaryEntry | None,
) -> tuple[float, float] | None:
    if latitude is not None and longitude is not None:
        return latitude, longitude
    if entry is not None and entry.latitude is not None and entry.longitude is not None:
        return entry.latitude, entry.longitude
    return None


def _weather_for(db: Session, coordinates: tuple[float, float] | None) -> WeatherObservation | None:
    if coordinates is None:
        return None
    try:
        return get_weather_change(db, *coordinates)
    except WeatherUnavailableError as exc:
        logger.warning("Погода недоступна, прогноз без неё: %s", exc)
        return None


def get_forecast(
    db: Session,
    user: User,
    now: datetime | None = None,
    *,
    latitude: float | None = None,
    longitude: float | None = None,
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

    coordinates = _coordinates(latitude, longitude, today_entry)
    weather = _weather_for(db, coordinates)
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
    features = PredictionInput(
        **build_features(
            entries,
            attack_dates,
            today,
            weather.weather_change_level if weather is not None else None,
        )
    )
    try:
        probability = load_model().predict(features)
        if not math.isfinite(probability) or not 0 <= probability <= 1:
            raise ValueError("Model returned an invalid probability")
    except Exception as exc:
        db.rollback()
        logger.exception("Forecast model could not produce a probability")
        raise HTTPException(
            status_code=503,
            detail="Прогноз временно недоступен. Повторите запрос позже.",
        ) from exc
    predictions_repo.create_prediction(
        db,
        user.id,
        features,
        probability,
        latitude=coordinates[0] if coordinates else None,
        longitude=coordinates[1] if coordinates else None,
        weather_observation_id=weather.id if weather is not None else None,
    )
    db.commit()
    return RiskForecastResponse(
        status="ready",
        **metadata,
        risk_level=str(round(probability * 100)),
        probability=probability,
        weather=to_response(weather) if weather is not None else None,
    )
