from pydantic import BaseModel


class RiskForecastResponse(BaseModel):
    risk_level: str
    probability: float
    factors: list[str]
    recommendations: list[str]
