from datetime import datetime, timedelta, timezone

import pytest
from app.schemas.forecast import RiskForecastResponse
from app.services import forecast
from pydantic import ValidationError

NOW = datetime(2026, 10, 20, 12, tzinfo=timezone.utc)
COMPLETE = {"sleep_hours": 7.5, "stress_level": 4, "caffeine_intake": 0}


@pytest.fixture(autouse=True)
def clock(monkeypatch):
    monkeypatch.setattr(forecast, "_now", lambda: NOW)


@pytest.fixture
def model(monkeypatch):
    class Model:
        def __init__(self):
            self.inputs = []

        def predict(self, features):
            self.inputs.append(features.model_dump())
            return 0.42

    instance = Model()
    monkeypatch.setattr(forecast, "load_model", lambda: instance)
    return instance


def login(client, email="forecast@example.com"):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "name": "Forecast",
            "password": "password123",
        },
    )
    assert response.status_code == 201
    response = client.post(
        "/api/v1/auth/login", json={"email": email, "password": "password123"}
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def diary(client, headers, values, day="2026-10-20"):
    response = client.put(f"/api/v1/diary/{day}", headers=headers, json=values)
    assert response.status_code == 200


def result(client, headers):
    response = client.get("/api/v1/forecast/risk", headers=headers)
    assert response.status_code == 200, response.text
    return response.json()


def test_empty_account_returns_no_probability_and_skips_model(client, model):
    data = result(client, login(client))
    assert data == {
        "status": "insufficient_data",
        "calculated_at": "2026-10-20T12:00:00Z",
        "prediction_date": "2026-10-21",
        "time_zone": "UTC",
        "horizon_days": 1,
        "risk_level": None,
        "probability": None,
        "factors": [],
        "recommendations": [],
        "missing_fields": ["sleep_hours", "stress_level", "caffeine_intake"],
        "message": "Для расчёта заполните сегодняшние значения сна, стресса и кофеина.",
    }
    assert model.inputs == []


@pytest.mark.parametrize("missing", ["sleep_hours", "stress_level", "caffeine_intake"])
def test_partial_record_lists_only_missing_fields(client, model, missing):
    headers = login(client)
    diary(client, headers, {**COMPLETE, missing: None})
    data = result(client, headers)
    assert data["status"] == "insufficient_data"
    assert data["missing_fields"] == [missing]
    assert data["probability"] is None
    assert model.inputs == []


def test_old_future_or_unrelated_factors_do_not_supply_today_inputs(client, model):
    headers = login(client)
    diary(client, headers, COMPLETE, "2026-10-19")
    diary(client, headers, COMPLETE, "2026-10-21")
    diary(
        client,
        headers,
        {"water_ml": 2000, "sleep_quality": 8, "headache_present": False},
    )
    assert result(client, headers)["missing_fields"] == [
        "sleep_hours",
        "stress_level",
        "caffeine_intake",
    ]
    assert model.inputs == []


def test_complete_record_produces_compatible_result_and_accepts_zero_caffeine(
    client, model
):
    headers = login(client)
    diary(client, headers, COMPLETE)
    data = result(client, headers)
    assert data["status"] == "ready"
    assert data["probability"] == 0.42
    assert data["risk_level"] == "42"
    assert data["calculated_at"] == "2026-10-20T12:00:00Z"
    assert data["prediction_date"] == "2026-10-21"
    assert data["missing_fields"] == []
    assert data["message"] is None
    assert model.inputs[0]["excessive_caffeine"] == 0
    # No invented minimum number of history days: this is an input gate only.
    assert model.inputs[0]["attacks_last_7_records"] == 0


def test_updating_and_clearing_inputs_recalculates_status_without_losing_diary(
    client, model
):
    headers = login(client)
    diary(client, headers, {"sleep_hours": 7.5})
    assert result(client, headers)["status"] == "insufficient_data"
    diary(client, headers, {"stress_level": 4, "caffeine_intake": 0})
    assert result(client, headers)["status"] == "ready"
    diary(client, headers, {"sleep_hours": None})
    assert result(client, headers)["missing_fields"] == ["sleep_hours"]
    saved = client.get("/api/v1/diary/2026-10-20", headers=headers).json()
    assert saved["stress_level"] == 4 and saved["caffeine_intake"] == 0
    assert len(model.inputs) == 1


@pytest.mark.parametrize(
    "zone,now,day,prediction",
    [
        ("Asia/Tomsk", "2026-12-31T20:00:00+00:00", "2027-01-01", "2027-01-02"),
        (
            "America/Los_Angeles",
            "2027-01-01T01:00:00+00:00",
            "2026-12-31",
            "2027-01-01",
        ),
        ("Europe/Berlin", "2026-03-28T23:30:00+00:00", "2026-03-29", "2026-03-30"),
        ("UTC", "2024-02-28T12:00:00+00:00", "2024-02-28", "2024-02-29"),
        ("Not/AZone", "2026-10-20T12:00:00+00:00", "2026-10-20", "2026-10-21"),
    ],
)
def test_local_calendar_and_utc_calculation_time(
    client, model, monkeypatch, zone, now, day, prediction
):
    instant = datetime.fromisoformat(now)
    monkeypatch.setattr(forecast, "_now", lambda: instant)
    headers = login(client)
    assert (
        client.put(
            "/api/v1/user/profile", headers=headers, json={"time_zone": zone}
        ).status_code
        == 200
    )
    # The date in the response is already available for insufficient_data.
    empty = result(client, headers)
    assert empty["prediction_date"] == prediction
    diary(client, headers, COMPLETE, day)
    ready = result(client, headers)
    assert ready["status"] == "ready"
    assert ready["prediction_date"] == prediction
    assert ready["time_zone"] == ("UTC" if zone == "Not/AZone" else zone)
    stamp = datetime.fromisoformat(ready["calculated_at"])
    assert stamp == instant and stamp.utcoffset() == timedelta(0)


def test_future_attack_times_excluded_even_on_current_day(client, model):
    headers = login(client)
    diary(client, headers, COMPLETE, "2026-10-19")
    diary(client, headers, COMPLETE)
    for start in (
        "2026-10-19T10:00:00Z",
        "2026-10-20T13:00:00Z",
        "2026-10-21T10:00:00Z",
    ):
        assert (
            client.post(
                "/api/v1/attacks",
                headers=headers,
                json={"start_time": start, "intensity": 6},
            ).status_code
            == 201
        )
    assert result(client, headers)["status"] == "ready"
    assert model.inputs[0]["days_since_last_attack"] == 1
    assert model.inputs[0]["attacks_last_7_records"] == 1


def test_accounts_cannot_supply_each_others_inputs_or_history(client, model):
    alice = login(client, "alice-forecast@example.com")
    bob = login(client, "bob-forecast@example.com")
    diary(client, alice, COMPLETE)
    diary(client, bob, COMPLETE, "2026-10-19")
    client.post(
        "/api/v1/attacks",
        headers=alice,
        json={"start_time": "2026-10-20T10:00:00Z", "intensity": 6},
    )
    assert result(client, alice)["status"] == "ready"
    assert result(client, bob)["status"] == "insufficient_data"
    client.post(
        "/api/v1/attacks",
        headers=alice,
        json={"start_time": "2026-10-19T10:00:00Z", "intensity": 6},
    )
    diary(client, bob, COMPLETE)
    assert result(client, bob)["status"] == "ready"
    assert model.inputs[-1]["attacks_last_7_records"] == 0
    assert model.inputs[-1]["days_since_last_attack"] == 1
    assert client.get("/api/v1/forecast/risk").status_code == 401
    assert len(model.inputs) == 2


def test_new_request_has_new_calculation_time(client, model, monkeypatch):
    headers = login(client)
    diary(client, headers, COMPLETE)
    assert result(client, headers)["calculated_at"] == "2026-10-20T12:00:00Z"
    monkeypatch.setattr(forecast, "_now", lambda: NOW + timedelta(minutes=5))
    assert result(client, headers)["calculated_at"] == "2026-10-20T12:05:00Z"


def test_model_failure_is_503_without_breaking_other_routes_or_empty_accounts(
    client, monkeypatch
):
    def unavailable():
        raise FileNotFoundError("internal/model/path.joblib")

    monkeypatch.setattr(forecast, "load_model", unavailable)
    headers = login(client)
    assert client.get("/health").status_code == 200
    assert result(client, headers)["status"] == "insufficient_data"
    diary(client, headers, COMPLETE)
    response = client.get("/api/v1/forecast/risk", headers=headers)
    assert response.status_code == 503
    assert "path.joblib" not in response.text
    assert client.get("/api/v1/diary/2026-10-20", headers=headers).status_code == 200


def test_app_starts_when_model_file_is_unavailable(monkeypatch):
    from app.main import app
    from app.ml import predictor
    from fastapi.testclient import TestClient

    def unavailable(*args):
        raise FileNotFoundError("missing-model.joblib")

    monkeypatch.setattr(predictor, "_predictor", None)
    monkeypatch.setattr(predictor, "Predictor", unavailable)
    with TestClient(app) as client:
        assert client.get("/health").status_code == 200


@pytest.mark.parametrize("probability", [float("nan"), float("inf"), -0.1, 1.1])
def test_invalid_model_results_do_not_become_ready(
    client, model, monkeypatch, probability
):
    headers = login(client)
    diary(client, headers, COMPLETE)
    monkeypatch.setattr(model, "predict", lambda _: probability)
    assert client.get("/api/v1/forecast/risk", headers=headers).status_code == 503


@pytest.mark.parametrize("probability", [0.0, 1.0])
def test_real_zero_probability_is_distinct_from_missing_data(
    client, model, monkeypatch, probability
):
    headers = login(client)
    diary(client, headers, COMPLETE)
    monkeypatch.setattr(model, "predict", lambda _: probability)
    data = result(client, headers)
    assert data["status"] == "ready" and data["probability"] == probability


def test_actual_model_is_used_by_ready_endpoint(client):
    headers = login(client)
    diary(client, headers, COMPLETE)
    data = result(client, headers)
    assert data["status"] == "ready" and 0 <= data["probability"] <= 1


def test_schema_rejects_probability_for_insufficient_data():
    with pytest.raises(ValidationError):
        RiskForecastResponse(
            status="insufficient_data",
            calculated_at=NOW,
            prediction_date=NOW.date(),
            time_zone="UTC",
            probability=0.16,
            missing_fields=["sleep_hours"],
        )


def test_openapi_publishes_status_metadata_and_model_unavailability(client):
    spec = client.get("/openapi.json").json()
    fields = spec["components"]["schemas"]["RiskForecastResponse"]["properties"]
    assert {
        "status",
        "calculated_at",
        "prediction_date",
        "time_zone",
        "horizon_days",
        "missing_fields",
    } <= fields.keys()
    assert "503" in spec["paths"]["/api/v1/forecast/risk"]["get"]["responses"]
