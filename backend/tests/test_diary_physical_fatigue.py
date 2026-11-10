from datetime import datetime, timedelta, timezone

import pytest

from app.api.deps import get_current_user
from app.db.session import get_db
from app.main import app
from app.ml.features import DiaryValues, build_features
from app.models.diary import DiaryEntry
from app.models.prediction import Prediction
from app.models.user import User

URL = "/api/v1/forecast/risk"


def today_utc():
    return datetime.now(timezone.utc).date()


@pytest.fixture
def session(client):
    db = next(app.dependency_overrides[get_db]())
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def user(client, session):
    user = User(email="fatigue@example.com", password_hash="x", name="Test")
    session.add(user)
    session.commit()
    app.dependency_overrides[get_current_user] = lambda: user
    return user


@pytest.mark.parametrize("value, expected", [(True, 1), (False, 0)])
def test_build_features_uses_todays_answer(value, expected):
    today = today_utc()

    features = build_features([DiaryValues(date=today, physical_fatigue=value)], [], today)

    assert features["physical_fatigue"] == expected


def test_build_features_skips_unanswered_question():
    today = today_utc()

    features = build_features([DiaryValues(date=today)], [], today)

    assert "physical_fatigue" not in features


def test_build_features_ignores_yesterdays_answer():
    today = today_utc()
    entries = [DiaryValues(date=today - timedelta(days=1), physical_fatigue=True)]

    assert "physical_fatigue" not in build_features(entries, [], today)


def test_diary_entry_without_answer_is_still_valid(session, user):
    session.add(DiaryEntry(user_id=user.id, date=today_utc(), sleep_hours=7.0))
    session.commit()

    entry = session.query(DiaryEntry).one()

    assert entry.physical_fatigue is None


def test_forecast_passes_answer_to_model_and_stores_it(client, session, user):
    session.add(DiaryEntry(user_id=user.id, date=today_utc(), physical_fatigue=True))
    session.commit()

    assert client.get(URL).status_code == 200

    assert session.query(Prediction).one().physical_fatigue == 1


@pytest.mark.parametrize("answer", [False, None])
def test_forecast_without_positive_answer_has_zero(client, session, user, answer):
    session.add(DiaryEntry(user_id=user.id, date=today_utc(), physical_fatigue=answer))
    session.commit()

    assert client.get(URL).status_code == 200

    assert session.query(Prediction).one().physical_fatigue == 0
