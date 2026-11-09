from datetime import datetime, timedelta, timezone

import pytest

from app.api.deps import get_current_user
from app.db.session import get_db
from app.main import app
from app.ml.features import build_features
from app.models.diary import DiaryEntry
from app.models.prediction import Prediction
from app.models.user import User
from app.models.weather_observation import WeatherObservation
from app.services import weather as weather_service
from app.services.weather import WeatherUnavailableError

URL = "/api/v1/forecast/risk"
PARAMS = {"latitude": 56.5, "longitude": 84.97}


def make_payload(prev_p, today_p, prev_t, today_t):
    times = [f"2026-11-08T{h:02d}:00" for h in range(24)] + [f"2026-11-09T{h:02d}:00" for h in range(24)]
    return {
        "timezone": "Asia/Tomsk",
        "hourly": {
            "time": times,
            "temperature_2m": [prev_t] * 24 + [today_t] * 24,
            "pressure_msl": [prev_p] * 24 + [today_p] * 24,
        },
    }


SIGNIFICANT = make_payload(1000, 1008, 10, 11)
MODERATE = make_payload(1000, 1004, 10, 11)
MINOR = make_payload(1000, 1001, 10, 11)


@pytest.fixture
def session():
    db = next(app.dependency_overrides[get_db]())
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def user(client, session):
    user = User(email="weather-forecast@example.com", password_hash="x", name="Test")
    session.add(user)
    session.commit()
    app.dependency_overrides[get_current_user] = lambda: user
    return user


@pytest.fixture
def fetch(monkeypatch):
    calls = []
    state = {"payload": MINOR, "error": None}

    def fake(latitude, longitude):
        calls.append((latitude, longitude))
        if state["error"] is not None:
            raise state["error"]
        return state["payload"]

    monkeypatch.setattr(weather_service, "fetch_hourly", fake)
    fake.calls = calls
    fake.state = state
    return fake


def predictions(session):
    return session.query(Prediction).order_by(Prediction.id).all()


def observations(session):
    return session.query(WeatherObservation).order_by(WeatherObservation.id).all()


def add_today_entry(session, user, **kwargs):
    today = datetime.now(timezone.utc).date()
    session.add(DiaryEntry(user_id=user.id, date=today + timedelta(days=kwargs.pop("offset", 0)), **kwargs))
    session.commit()


def test_significant_change_sets_model_feature(client, session, user, fetch):
    fetch.state["payload"] = SIGNIFICANT

    response = client.get(URL, params=PARAMS)

    assert response.status_code == 200
    body = response.json()
    assert body["weather"]["weather_change"] == 2
    assert body["weather"]["label"] == "significant"
    row = predictions(session)[0]
    assert row.weather_change == 1
    assert row.latitude == PARAMS["latitude"]
    assert row.longitude == PARAMS["longitude"]
    saved = observations(session)
    assert len(saved) == 1
    assert row.weather_observation_id == saved[0].id == body["weather"]["record_id"]
    assert row.probability == body["probability"]


@pytest.mark.parametrize("payload, level", [(MODERATE, 1), (MINOR, 0)])
def test_lower_levels_are_not_a_trigger(client, session, user, fetch, payload, level):
    fetch.state["payload"] = payload

    response = client.get(URL, params=PARAMS)

    assert response.json()["weather"]["weather_change"] == level
    assert predictions(session)[0].weather_change == 0
    assert predictions(session)[0].weather_observation_id is not None


@pytest.mark.parametrize(
    "failure",
    [WeatherUnavailableError("down"), None],
    ids=["upstream-error", "null-in-data"],
)
def test_weather_failure_does_not_break_prediction(client, session, user, fetch, failure):
    if failure is not None:
        fetch.state["error"] = failure
    else:
        broken = make_payload(1000, 1008, 10, 11)
        broken["hourly"]["pressure_msl"][3] = None
        fetch.state["payload"] = broken

    response = client.get(URL, params=PARAMS)

    assert response.status_code == 200
    assert response.json()["weather"] is None
    row = predictions(session)[0]
    assert row.weather_change == 0
    assert row.weather_observation_id is None
    assert row.latitude == PARAMS["latitude"]
    assert observations(session) == []


def test_no_coordinates_anywhere_skips_weather(client, session, user, fetch):
    response = client.get(URL)

    assert response.status_code == 200
    assert response.json()["weather"] is None
    assert fetch.calls == []
    row = predictions(session)[0]
    assert row.latitude is None
    assert row.longitude is None
    assert row.weather_observation_id is None
    assert row.weather_change == 0


def test_falls_back_to_todays_diary_coordinates(client, session, user, fetch):
    add_today_entry(session, user, latitude=55.75, longitude=37.62)
    fetch.state["payload"] = SIGNIFICANT

    response = client.get(URL)

    assert response.json()["weather"]["weather_change"] == 2
    assert fetch.calls == [(55.75, 37.62)]
    row = predictions(session)[0]
    assert (row.latitude, row.longitude) == (55.75, 37.62)
    assert row.weather_change == 1


def test_query_parameters_override_diary_coordinates(client, session, user, fetch):
    add_today_entry(session, user, latitude=55.75, longitude=37.62)

    client.get(URL, params=PARAMS)

    assert fetch.calls == [(PARAMS["latitude"], PARAMS["longitude"])]


def test_diary_entry_without_coordinates_is_ignored(client, session, user, fetch):
    add_today_entry(session, user, sleep_hours=7.0)

    client.get(URL)

    assert fetch.calls == []


def test_only_todays_diary_entry_is_used(client, session, user, fetch):
    add_today_entry(session, user, offset=-1, latitude=55.75, longitude=37.62)

    client.get(URL)

    assert fetch.calls == []


def test_half_filled_diary_coordinates_are_ignored(client, session, user, fetch):
    add_today_entry(session, user, latitude=55.75)

    client.get(URL)

    assert fetch.calls == []


@pytest.mark.parametrize(
    "params",
    [{"latitude": 1}, {"longitude": 1}, {"latitude": 91, "longitude": 0}, {"latitude": 0, "longitude": 181}],
)
def test_invalid_query_parameters_return_422(client, session, user, fetch, params):
    response = client.get(URL, params=params)

    assert response.status_code == 422
    assert predictions(session) == []
    assert fetch.calls == []


def test_response_without_weather_keeps_old_fields(client, session, user, fetch):
    body = client.get(URL).json()

    assert body["risk_level"] == str(round(body["probability"] * 100))
    assert body["factors"] == []
    assert body["recommendations"] == []


@pytest.mark.parametrize("level, expected", [(2, 1), (1, 0), (0, 0)])
def test_build_features_translates_level(level, expected):
    today = datetime.now(timezone.utc).date()

    features = build_features([], [], today, weather_change_level=level)

    assert features["weather_change"] == expected


def test_build_features_without_level_has_no_weather_key():
    today = datetime.now(timezone.utc).date()

    assert "weather_change" not in build_features([], [], today)
