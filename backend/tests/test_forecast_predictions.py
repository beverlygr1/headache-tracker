from datetime import date, datetime, time, timedelta, timezone

import pytest

from app.api.deps import get_current_user
from app.db.session import get_db
from app.main import app
from app.ml.prediction_schemas import FEATURE_COLS
from app.models.attack import Attack
from app.models.diary import DiaryEntry
from app.models.prediction import Prediction
from app.models.user import User
from app.services.forecast import predict_probability

URL = "/api/v1/forecast/risk"


@pytest.fixture
def session():
    db = next(app.dependency_overrides[get_db]())
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def user(client, session):
    user = User(email="forecast@example.com", password_hash="x", name="Test")
    session.add(user)
    session.commit()
    app.dependency_overrides[get_current_user] = lambda: user
    return user


def all_predictions(session):
    return session.query(Prediction).order_by(Prediction.id).all()


def test_forecast_response_is_unchanged_and_prediction_is_stored(client, session, user):
    response = client.get(URL)

    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"risk_level", "probability", "factors", "recommendations", "weather"}
    assert body["weather"] is None
    assert body["risk_level"] == str(round(body["probability"] * 100))
    rows = all_predictions(session)
    assert len(rows) == 1
    assert rows[0].user_id == user.id
    assert rows[0].probability == body["probability"]


def test_stored_features_match_diary_and_attacks(client, session, user):
    today = datetime.now(timezone.utc).date()
    yesterday = today - timedelta(days=1)
    session.add_all(
        [
            DiaryEntry(user_id=user.id, date=yesterday, sleep_hours=7.0, stress_level=3, caffeine_intake=100),
            DiaryEntry(user_id=user.id, date=today, sleep_hours=5.0, stress_level=8, caffeine_intake=500),
            Attack(
                user_id=user.id,
                start_time=datetime.combine(yesterday, time(12, 0), tzinfo=timezone.utc),
                intensity=5,
            ),
        ]
    )
    session.commit()

    response = client.get(URL)

    assert response.status_code == 200
    row = all_predictions(session)[0]
    stored = {name: getattr(row, name) for name in FEATURE_COLS}
    expected = {name: 0 for name in FEATURE_COLS}
    expected.update(
        stress=1,
        lack_of_sleep=1,
        excessive_caffeine=1,
        days_since_last_attack=1,
        attacks_last_7_records=1,
    )
    assert stored == expected


def test_prediction_without_weather_has_empty_weather_columns(client, session, user):
    client.get(URL)

    row = all_predictions(session)[0]
    assert row.latitude is None
    assert row.longitude is None
    assert row.weather_observation_id is None
    assert row.weather_change == 0


def test_each_call_stores_a_row(client, session, user):
    client.get(URL)
    client.get(URL)

    assert len(all_predictions(session)) == 2


def test_requires_auth(client, session):
    assert client.get(URL).status_code == 401
    assert all_predictions(session) == []


def test_predict_probability_does_not_store(client, session, user):
    probability = predict_probability(session, user)

    assert 0.0 <= probability <= 1.0
    assert all_predictions(session) == []
