from fastapi import APIRouter

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
def get_risk_forecast(current_user: CurrentUser, db: DbSession) -> RiskForecastResponse:
    return get_forecast(db, current_user)
