from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import CurrentUser
from app.schemas.forecast import RiskForecastResponse

router = APIRouter(prefix="/forecast", tags=["Прогнозирование"])


@router.get("/risk", response_model=RiskForecastResponse)
def get_risk_forecast(current_user: CurrentUser, lat: float | None = Query(None, ge=-90, le=90), lon: float | None = Query(None, ge=-180, le=180)) -> RiskForecastResponse:
    raise HTTPException(status_code=status.HTTP_501_NOT_IMPLEMENTED, detail="ML-прогноз риска пока не реализован. Endpoint зарезервирован под следующий этап проекта.")
