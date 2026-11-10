from typing import Annotated

from fastapi import APIRouter, HTTPException, Query

from app.api.deps import CurrentUser, DbSession
from app.schemas.forecast import RiskForecastResponse
from app.services.forecast import get_forecast

router = APIRouter(prefix="/forecast", tags=["Прогнозирование"])


@router.get(
    "/risk",
    response_model=RiskForecastResponse,
    summary="Экспериментальный прогноз на следующий день",
    description="HTTP 200: ready с вероятностью либо insufficient_data с null и списком недостающих сегодняшних полей. Даты учитывают часовой пояс профиля.",
    responses={
        503: {"description": "Модель временно недоступна; повторите запрос позже"}
    },
)
def get_risk_forecast(
    current_user: CurrentUser,
    db: DbSession,
    latitude: Annotated[float | None, Query(ge=-90, le=90)] = None,
    longitude: Annotated[float | None, Query(ge=-180, le=180)] = None,
) -> RiskForecastResponse:
    if (latitude is None) != (longitude is None):
        raise HTTPException(
            status_code=422,
            detail="Параметры latitude и longitude нужно передавать вместе",
        )
    return get_forecast(db, current_user, latitude=latitude, longitude=longitude)
