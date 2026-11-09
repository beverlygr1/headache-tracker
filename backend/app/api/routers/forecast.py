from typing import Annotated

from fastapi import APIRouter, HTTPException, Query

from app.api.deps import CurrentUser, DbSession
from app.api.routers.weather import to_response
from app.schemas.forecast import RiskForecastResponse
from app.services.forecast import predict_and_store

router = APIRouter(prefix="/forecast", tags=["Прогнозирование"])


@router.get("/risk", response_model=RiskForecastResponse)
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
    result = predict_and_store(db, current_user, latitude=latitude, longitude=longitude)
    return RiskForecastResponse(
        risk_level=str(round(result.probability * 100)),
        probability=result.probability,
        factors=[],
        recommendations=[],
        weather=to_response(result.weather) if result.weather is not None else None,
    )
