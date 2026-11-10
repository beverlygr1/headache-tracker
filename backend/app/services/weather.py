from datetime import date
from statistics import fmean

import httpx
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.weather_observation import WeatherObservation
from app.schemas.weather import WeatherChangeResponse, WeatherDetails

SOURCE = "open-meteo"
HOURS_PER_DAY = 24
LEVEL_LABELS = {0: "minor", 1: "moderate", 2: "significant"}
HOURLY_VARIABLES = ("temperature_2m", "pressure_msl")


class WeatherUnavailableError(Exception):
    pass

def level_for(delta: float, moderate: float, significant: float) -> int:
    if delta >= significant:
        return 2
    if delta >= moderate:
        return 1
    return 0


def fetch_hourly(latitude: float, longitude: float) -> dict:
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "hourly": ",".join(HOURLY_VARIABLES),
        "past_days": 1,
        "forecast_days": 1,
        "timezone": "auto",
    }
    try:
        response = httpx.get(
            settings.open_meteo_url,
            params=params,
            timeout=settings.weather_timeout_seconds,
        )
        response.raise_for_status()
        payload = response.json()
    except (httpx.HTTPError, ValueError) as exc:
        raise WeatherUnavailableError(f"Open-Meteo: {exc}") from exc
    if not isinstance(payload, dict):
        raise WeatherUnavailableError("Open-Meteo: неожиданный формат ответа")
    return payload


def _is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def parse_hourly(payload: dict) -> dict:
    try:
        timezone = payload["timezone"]
        hourly = payload["hourly"]
        times = hourly["time"]
        temperatures = hourly["temperature_2m"]
        pressures = hourly["pressure_msl"]
    except (KeyError, TypeError) as exc:
        raise WeatherUnavailableError("Open-Meteo: неожиданный формат ответа") from exc

    if not isinstance(timezone, str) or not timezone:
        raise WeatherUnavailableError("Open-Meteo: нет часового пояса")
    if not (isinstance(times, list) and isinstance(temperatures, list) and isinstance(pressures, list)):
        raise WeatherUnavailableError("Open-Meteo: неожиданный формат ответа")
    if not (len(times) == len(temperatures) == len(pressures)):
        raise WeatherUnavailableError("Open-Meteo: ряды разной длины")
    if not all(_is_number(v) for v in temperatures) or not all(_is_number(v) for v in pressures):
        raise WeatherUnavailableError("Open-Meteo: в данных есть пропуски")

    days: dict[date, dict[str, list[float]]] = {}
    for stamp, temperature, pressure in zip(times, temperatures, pressures):
        try:
            day = date.fromisoformat(str(stamp)[:10])
        except ValueError as exc:
            raise WeatherUnavailableError("Open-Meteo: неверная дата в ответе") from exc
        bucket = days.setdefault(day, {"temperature": [], "pressure": []})
        bucket["temperature"].append(float(temperature))
        bucket["pressure"].append(float(pressure))

    if len(days) != 2 or any(len(b["temperature"]) != HOURS_PER_DAY for b in days.values()):
        raise WeatherUnavailableError("Open-Meteo: ожидалось по 24 часа за вчера и сегодня")

    prev_day, today = sorted(days)
    prev, cur = days[prev_day], days[today]
    return {
        "timezone": timezone,
        "local_date": today,
        "mean_pressure_msl_prev": fmean(prev["pressure"]),
        "mean_pressure_msl_today": fmean(cur["pressure"]),
        "mean_temperature_prev": fmean(prev["temperature"]),
        "mean_temperature_today": fmean(cur["temperature"]),
        "raw_hourly": {
            "time": list(times),
            "temperature_2m": list(temperatures),
            "pressure_msl": list(pressures),
        },
    }


def get_weather_change(db: Session, latitude: float, longitude: float) -> WeatherObservation:
    parsed = parse_hourly(fetch_hourly(latitude, longitude))

    delta_pressure = abs(parsed["mean_pressure_msl_today"] - parsed["mean_pressure_msl_prev"])
    delta_temperature = abs(parsed["mean_temperature_today"] - parsed["mean_temperature_prev"])
    pressure_level = level_for(
        delta_pressure,
        settings.weather_pressure_moderate_hpa,
        settings.weather_pressure_significant_hpa,
    )
    temperature_level = level_for(
        delta_temperature,
        settings.weather_temperature_moderate_c,
        settings.weather_temperature_significant_c,
    )

    observation = WeatherObservation(
        latitude=latitude,
        longitude=longitude,
        local_date=parsed["local_date"],
        timezone=parsed["timezone"],
        source=SOURCE,
        mean_pressure_msl_today=parsed["mean_pressure_msl_today"],
        mean_pressure_msl_prev=parsed["mean_pressure_msl_prev"],
        mean_temperature_today=parsed["mean_temperature_today"],
        mean_temperature_prev=parsed["mean_temperature_prev"],
        delta_pressure_hpa=delta_pressure,
        delta_temperature_c=delta_temperature,
        pressure_level=pressure_level,
        temperature_level=temperature_level,
        weather_change_level=max(pressure_level, temperature_level),
        raw_hourly=parsed["raw_hourly"],
    )
    db.add(observation)
    db.flush()
    return observation


def to_response(observation: WeatherObservation) -> WeatherChangeResponse:
    return WeatherChangeResponse(
        weather_change=observation.weather_change_level,
        label=LEVEL_LABELS[observation.weather_change_level],
        date=observation.local_date,
        timezone=observation.timezone,
        details=WeatherDetails(
            delta_pressure_hpa=round(observation.delta_pressure_hpa, 2),
            delta_temperature_c=round(observation.delta_temperature_c, 2),
            pressure_level=observation.pressure_level,
            temperature_level=observation.temperature_level,
        ),
        source=observation.source,
        record_id=observation.id,
    )
