from datetime import date
from typing import Literal

from pydantic import AwareDatetime, BaseModel, Field, model_validator

ForecastInputField = Literal["sleep_hours", "stress_level", "caffeine_intake"]


class RiskForecastResponse(BaseModel):
    status: Literal["ready", "insufficient_data"]
    calculated_at: AwareDatetime = Field(
        description="Момент расчёта или проверки достаточности данных в UTC"
    )
    prediction_date: date = Field(
        description="Следующая календарная дата в часовом поясе пользователя"
    )
    time_zone: str = Field(
        description="Использованный часовой пояс; UTC при отсутствии корректной настройки"
    )
    horizon_days: Literal[1] = 1
    risk_level: str | None = Field(
        None,
        description="Округлённый процент строкой, как в прежнем API; null без расчёта",
    )
    probability: float | None = Field(None, ge=0, le=1, allow_inf_nan=False)
    factors: list[str] = Field(default_factory=list)
    recommendations: list[str] = Field(default_factory=list)
    missing_fields: list[ForecastInputField] = Field(default_factory=list)
    message: str | None = None

    @model_validator(mode="after")
    def validate_status(self):
        if self.status == "ready":
            if (
                self.probability is None
                or self.risk_level is None
                or self.missing_fields
            ):
                raise ValueError(
                    "Готовый прогноз должен содержать вероятность без недостающих полей"
                )
        elif (
            self.probability is not None
            or self.risk_level is not None
            or not self.missing_fields
        ):
            raise ValueError(
                "Без достаточных данных вероятность отсутствует и указаны недостающие поля"
            )
        return self
