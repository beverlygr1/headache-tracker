import httpx
import pytest

from app.api.deps import get_current_user
from app.core.config import settings
from app.db.session import get_db
from app.main import app
from app.models.user import User
from app.models.weather_observation import WeatherObservation
from app.services import weather as weather_service
from app.services.weather import WeatherUnavailableError, level_for, parse_hourly

URL = "/api/v1/weather/change"
PARAMS = {"latitude": 56.5, "longitude": 84.97}


def make_payload(prev_p, today_p, prev_t, today_t, timezone="Asia/Tomsk"):
    times = [f"2026-11-08T{h:02d}:00" for h in range(24)] + [f"2026-11-09T{h:02d}:00" for h in range(24)]
    return {
        "timezone": timezone,
        "hourly": {
            "time": times,
            "temperature_2m": [prev_t] * 24 + [today_t] * 24,
            "pressure_msl": [prev_p] * 24 + [today_p] * 24,
        },
    }


@pytest.fixture
def authed(client):
    app.dependency_overrides[get_current_user] = lambda: User(id=1, email="a@example.com")
    return client


@pytest.fixture
def rows():
    def _rows():
        db = next(app.dependency_overrides[get_db]())
        try:
            return db.query(WeatherObservation).all()
        finally:
            db.close()

    return _rows


def use_payload(monkeypatch, payload):
    monkeypatch.setattr(weather_service, "fetch_hourly", lambda lat, lon: payload)


@pytest.mark.parametrize(
    "delta, expected",
    [(0.0, 0), (3.29, 0), (3.3, 1), (6.69, 1), (6.7, 2), (20.0, 2)],
)
def test_level_for_pressure_boundaries(delta, expected):
    assert level_for(delta, 3.3, 6.7) == expected


@pytest.mark.parametrize(
    "delta, expected",
    [(0.0, 0), (2.49, 0), (2.5, 1), (4.99, 1), (5.0, 2), (12.0, 2)],
)
def test_level_for_temperature_boundaries(delta, expected):
    assert level_for(delta, 2.5, 5.0) == expected


@pytest.mark.parametrize(
    "payload_args, level, pressure_level, temperature_level",
    [
        ((1000, 1001, 10, 11), 0, 0, 0),
        ((1000, 1004, 10, 11), 1, 1, 0),
        ((1000, 1001, 10, 13), 1, 0, 1),
        ((1000, 1008, 10, 11), 2, 2, 0),
        ((1000, 1001, 10, 16), 2, 0, 2),
        ((1008, 1000, 10, 11), 2, 2, 0),
        ((1000, 1004, 10, 16), 2, 1, 2),
    ],
)
def test_weather_change_levels(authed, monkeypatch, rows, payload_args, level, pressure_level, temperature_level):
    use_payload(monkeypatch, make_payload(*payload_args))

    response = authed.get(URL, params=PARAMS)

    assert response.status_code == 200
    body = response.json()
    assert body["weather_change"] == level
    assert body["label"] == {0: "minor", 1: "moderate", 2: "significant"}[level]
    assert body["details"]["pressure_level"] == pressure_level
    assert body["details"]["temperature_level"] == temperature_level
    assert body["date"] == "2026-11-09"
    assert body["timezone"] == "Asia/Tomsk"
    assert body["source"] == "open-meteo"
    saved = rows()
    assert len(saved) == 1
    assert saved[0].id == body["record_id"]
    assert saved[0].weather_change_level == level
    assert saved[0].latitude == PARAMS["latitude"]
    assert saved[0].longitude == PARAMS["longitude"]
    assert len(saved[0].raw_hourly["time"]) == 48


def test_every_call_creates_new_row(authed, monkeypatch, rows):
    use_payload(monkeypatch, make_payload(1000, 1001, 10, 11))
    authed.get(URL, params=PARAMS)
    authed.get(URL, params=PARAMS)
    assert len(rows()) == 2


def test_upstream_failure_returns_502_and_saves_nothing(authed, monkeypatch, rows):
    def boom(lat, lon):
        raise WeatherUnavailableError("down")

    monkeypatch.setattr(weather_service, "fetch_hourly", boom)

    response = authed.get(URL, params=PARAMS)

    assert response.status_code == 502
    assert rows() == []


def test_null_in_hourly_returns_502_and_saves_nothing(authed, monkeypatch, rows):
    payload = make_payload(1000, 1001, 10, 11)
    payload["hourly"]["pressure_msl"][5] = None
    use_payload(monkeypatch, payload)

    response = authed.get(URL, params=PARAMS)

    assert response.status_code == 502
    assert rows() == []


@pytest.mark.parametrize("latitude, longitude", [(91, 0), (-91, 0), (0, 181), (0, -181)])
def test_invalid_coordinates_return_422(authed, latitude, longitude):
    response = authed.get(URL, params={"latitude": latitude, "longitude": longitude})
    assert response.status_code == 422


def test_missing_coordinates_return_422(authed):
    assert authed.get(URL, params={"latitude": 1}).status_code == 422


def test_requires_auth(client):
    assert client.get(URL, params=PARAMS).status_code == 401


def test_parse_rejects_wrong_hour_count():
    payload = make_payload(1000, 1001, 10, 11)
    for key in ("time", "temperature_2m", "pressure_msl"):
        payload["hourly"][key] = payload["hourly"][key][:-1]
    with pytest.raises(WeatherUnavailableError):
        parse_hourly(payload)


@pytest.mark.parametrize("broken", [{}, {"timezone": "UTC"}, {"timezone": "UTC", "hourly": {}}, {"timezone": "", "hourly": {}}])
def test_parse_rejects_malformed_payload(broken):
    with pytest.raises(WeatherUnavailableError):
        parse_hourly(broken)


def test_parse_computes_means():
    parsed = parse_hourly(make_payload(1000, 1004, 10, 13))
    assert parsed["local_date"].isoformat() == "2026-11-09"
    assert parsed["mean_pressure_msl_prev"] == pytest.approx(1000)
    assert parsed["mean_pressure_msl_today"] == pytest.approx(1004)
    assert parsed["mean_temperature_prev"] == pytest.approx(10)
    assert parsed["mean_temperature_today"] == pytest.approx(13)


def test_fetch_hourly_sends_expected_params(monkeypatch):
    captured = {}

    def fake_get(url, params, timeout):
        captured.update(url=url, params=params, timeout=timeout)
        return httpx.Response(200, json={"ok": True}, request=httpx.Request("GET", url))

    monkeypatch.setattr(weather_service.httpx, "get", fake_get)

    assert weather_service.fetch_hourly(56.5, 84.97) == {"ok": True}
    assert captured["params"]["hourly"] == "temperature_2m,pressure_msl"
    assert captured["params"]["past_days"] == 1
    assert captured["params"]["forecast_days"] == 1
    assert captured["params"]["timezone"] == "auto"
    assert captured["timeout"] == 5.0


@pytest.mark.parametrize(
    "outcome",
    [
        httpx.ConnectTimeout("timeout"),
        httpx.Response(500, request=httpx.Request("GET", "https://x")),
        httpx.Response(200, content=b"not json", request=httpx.Request("GET", "https://x")),
        httpx.Response(200, json=[1, 2], request=httpx.Request("GET", "https://x")),
    ],
)
def test_fetch_hourly_wraps_failures(monkeypatch, outcome):
    def fake_get(url, params, timeout):
        if isinstance(outcome, Exception):
            raise outcome
        return outcome

    monkeypatch.setattr(weather_service.httpx, "get", fake_get)

    with pytest.raises(WeatherUnavailableError):
        weather_service.fetch_hourly(56.5, 84.97)


def test_thresholds_come_from_settings(authed, monkeypatch):
    use_payload(monkeypatch, make_payload(1000, 1004, 10, 11))
    monkeypatch.setattr(settings, "weather_pressure_moderate_hpa", 10.0)
    monkeypatch.setattr(settings, "weather_pressure_significant_hpa", 20.0)
    assert authed.get(URL, params=PARAMS).json()["weather_change"] == 0

    monkeypatch.setattr(settings, "weather_pressure_moderate_hpa", 1.0)
    monkeypatch.setattr(settings, "weather_pressure_significant_hpa", 3.0)
    assert authed.get(URL, params=PARAMS).json()["weather_change"] == 2
