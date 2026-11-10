from datetime import datetime, timezone

import pytest

from app.api.deps import get_current_user
from app.db.session import get_db
from app.main import app
from app.models.prediction import Prediction
from app.models.user import User


def today_iso():
    return datetime.now(timezone.utc).date().isoformat()


@pytest.fixture
def session(client):
    db = next(app.dependency_overrides[get_db]())
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def user(client, session):
    user = User(email="diary-fatigue@example.com", password_hash="x", name="Test")
    session.add(user)
    session.commit()
    app.dependency_overrides[get_current_user] = lambda: user
    return user


def put(client, body, day=None):
    return client.put(f"/api/v1/diary/{day or today_iso()}", json=body)


@pytest.mark.parametrize("value", [True, False])
def test_answer_is_saved_and_returned(client, user, value):
    response = put(client, {"physical_fatigue": value})

    assert response.status_code == 200
    assert response.json()["physical_fatigue"] is value
    assert client.get(f"/api/v1/diary/{today_iso()}").json()["physical_fatigue"] is value


def test_field_is_optional_for_old_clients(client, user):
    response = put(client, {"sleep_hours": 7.5, "stress_level": 4})

    assert response.status_code == 200
    assert response.json()["physical_fatigue"] is None


def test_omitted_field_keeps_previous_answer(client, user):
    put(client, {"physical_fatigue": True})

    response = put(client, {"sleep_hours": 6.0})

    assert response.json()["physical_fatigue"] is True
    assert response.json()["sleep_hours"] == 6.0


def test_explicit_null_clears_answer(client, user):
    put(client, {"physical_fatigue": True})

    response = put(client, {"physical_fatigue": None})

    assert response.json()["physical_fatigue"] is None


@pytest.mark.parametrize("value", ["yes", 1, "true"])
def test_non_boolean_value_is_rejected(client, user, value):
    assert put(client, {"physical_fatigue": value}).status_code == 422


def test_list_contains_field(client, user):
    put(client, {"physical_fatigue": True})

    body = client.get("/api/v1/diary").json()

    assert body[0]["physical_fatigue"] is True


def test_answer_reaches_the_forecast(client, session, user):
    put(client, {"physical_fatigue": True})

    assert client.get("/api/v1/forecast/risk").status_code == 200

    assert session.query(Prediction).one().physical_fatigue == 1
