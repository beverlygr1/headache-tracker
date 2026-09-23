from enum import Enum

from pydantic import BaseModel


class PeriodEnum(str, Enum):
    week = "week"
    month = "month"
    year = "year"


class ExportFormatEnum(str, Enum):
    pdf = "pdf"
    csv = "csv"


class AnalyticsSummaryResponse(BaseModel):
    period: PeriodEnum
    total_attacks: int
    avg_intensity: float
    avg_duration_minutes: float


class TriggerCorrelation(BaseModel):
    factor: str
    correlation_score: float
    description: str


class AnalyticsTriggersResponse(BaseModel):
    top_triggers: list[TriggerCorrelation]
