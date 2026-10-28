from datetime import date
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
    completed_attacks: int = 0
    from_date: date
    to_date: date
    time_zone: str


class IntensityPoint(BaseModel):
    date: date
    total_attacks: int
    avg_intensity: float | None
    max_intensity: int | None
    completed_attacks: int = 0
    avg_duration_minutes: float | None = None
    diary_recorded: bool
    headache_present: bool | None


class AnalyticsIntensityResponse(BaseModel):
    period: PeriodEnum
    from_date: date
    to_date: date
    time_zone: str
    points: list[IntensityPoint]


class TriggerCorrelation(BaseModel):
    factor: str
    correlation_score: float
    description: str


class AnalyticsTriggersResponse(BaseModel):
    top_triggers: list[TriggerCorrelation]
