import logging
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import CurrentUser, DbSession
from app.schemas.weather import WeatherChangeResponse
from app.services.weather import (
    WeatherUnavailableError,
    get_weather_change,
    to_response,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/weather", tags=["Погода"])


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
