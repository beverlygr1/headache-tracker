import logging
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import CurrentUser, DbSession
from app.models.weather_observation import WeatherObservation
from app.schemas.weather import WeatherChangeResponse, WeatherDetails
from app.services.weather import LEVEL_LABELS, WeatherUnavailableError, get_weather_change

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/weather", tags=["Погода"])


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


@router.get("/change", response_model=WeatherChangeResponse)
def get_change(
    _current_user: CurrentUser,
    db: DbSession,
    latitude: Annotated[float, Query(ge=-90, le=90)],
    longitude: Annotated[float, Query(ge=-180, le=180)],
) -> WeatherChangeResponse:
    try:
        observation = get_weather_change(db, latitude, longitude)
    except WeatherUnavailableError as exc:
        db.rollback()
        logger.warning("Погода недоступна: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY, detail="Сервис погоды недоступен"
        ) from exc
    db.commit()
    return to_response(observation)
