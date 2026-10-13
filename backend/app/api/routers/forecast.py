from fastapi import APIRouter

from app.api.deps import CurrentUser, DbSession
from app.schemas.forecast import RiskForecastResponse
from app.services.forecast import predict_probability

router = APIRouter(prefix="/forecast", tags=["Прогнозирование"])


@router.get("/risk", response_model=RiskForecastResponse)
def get_risk_forecast(current_user: CurrentUser, db: DbSession) -> RiskForecastResponse:
    probability = predict_probability(db, current_user)
    return RiskForecastResponse(
        risk_level=str(round(probability * 100)),
        probability=probability,
        factors=[],
        recommendations=[],
    )
