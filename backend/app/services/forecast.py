from datetime import date, datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy.orm import Session

from app.ml.features import DiaryValues, build_features
from app.ml.predictor import load_model
from app.ml.prediction_schemas import PredictionInput
from app.models.user import User
from app.repositories import attacks as attacks_repo
from app.repositories import diary as diary_repo


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


def predict_probability(db: Session, user: User, now: datetime | None = None) -> float:
    tz = _user_tz(user)
    today = (now or datetime.now(timezone.utc)).astimezone(tz).date()

    entries = [
        DiaryValues(
            date=e.date,
            sleep_hours=e.sleep_hours,
            stress_level=e.stress_level,
            caffeine_intake=e.caffeine_intake,
        )
        for e in diary_repo.list_entries(db, user.id, None, today)
    ]
    attack_dates = [
        _local_date(start, tz)
        for start in attacks_repo.list_start_times(db, user.id)
    ]

    features = build_features(entries, attack_dates, today)
    return load_model().predict(PredictionInput(**features))
