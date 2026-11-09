import logging
from dataclasses import dataclass
from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy.orm import Session

from app.ml.features import DiaryValues, build_features
from app.ml.predictor import load_model
from app.ml.prediction_schemas import PredictionInput
from app.models.diary import DiaryEntry
from app.models.user import User
from app.models.weather_observation import WeatherObservation
from app.repositories import attacks as attacks_repo
from app.repositories import diary as diary_repo
from app.repositories import predictions as predictions_repo
from app.services.weather import WeatherUnavailableError, get_weather_change

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ForecastResult:
    probability: float
    weather: WeatherObservation | None


def _user_tz(user: User):
    if user.time_zone:
        try:
            return ZoneInfo(user.time_zone)
        except (ZoneInfoNotFoundError, ValueError):
            pass
    return timezone.utc


def _local_date(moment: datetime, tz) -> date:
    if moment.tzinfo is None:
        moment = moment.replace(tzinfo=timezone.utc)
    return moment.astimezone(tz).date()


def _today(user: User, now: datetime | None):
    tz = _user_tz(user)
    return tz, (now or datetime.now(timezone.utc)).astimezone(tz).date()


def _prediction_input(
    db: Session,
    user: User,
    tz,
    today: date,
    rows: list[DiaryEntry],
    weather_change_level: int | None = None,
) -> PredictionInput:
    entries = [
        DiaryValues(
            date=e.date,
            sleep_hours=e.sleep_hours,
            stress_level=e.stress_level,
            caffeine_intake=e.caffeine_intake,
        )
        for e in rows
    ]
    attack_dates = [
        _local_date(start, tz)
        for start in attacks_repo.list_start_times(db, user.id)
    ]

    features = build_features(entries, attack_dates, today, weather_change_level)
    return PredictionInput(**features)


def _coordinates(
    latitude: float | None,
    longitude: float | None,
    rows: list[DiaryEntry],
    today: date,
) -> tuple[float, float] | None:
    if latitude is not None and longitude is not None:
        return latitude, longitude
    entry = next((e for e in rows if e.date == today), None)
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


def predict_probability(db: Session, user: User, now: datetime | None = None) -> float:
    tz, today = _today(user, now)
    rows = diary_repo.list_entries(db, user.id, None, today)
    return load_model().predict(_prediction_input(db, user, tz, today, rows))


def predict_and_store(
    db: Session,
    user: User,
    now: datetime | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
) -> ForecastResult:
    tz, today = _today(user, now)
    rows = diary_repo.list_entries(db, user.id, None, today)

    coordinates = _coordinates(latitude, longitude, rows, today)
    weather = _weather_for(db, coordinates)

    features = _prediction_input(
        db,
        user,
        tz,
        today,
        rows,
        weather.weather_change_level if weather is not None else None,
    )
    probability = load_model().predict(features)

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
    return ForecastResult(probability=probability, weather=weather)
