from datetime import date
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.api.deps import CurrentUser, DbSession
from app.schemas.analytics import (
    AnalyticsIntensityResponse,
    AnalyticsSummaryResponse,
    AnalyticsTriggersResponse,
    ExportFormatEnum,
    PeriodEnum,
)
from app.services import analytics as analytics_service

router = APIRouter(prefix="/analytics", tags=["Аналитика"])


@router.get("/summary", response_model=AnalyticsSummaryResponse)
def get_analytics_summary(
    db: DbSession,
    current_user: CurrentUser,
    period: Annotated[PeriodEnum, Query()] = PeriodEnum.month,
    from_date: Annotated[date | None, Query()] = None,
    to_date: Annotated[date | None, Query()] = None,
    time_zone: Annotated[str, Query(max_length=64)] = "UTC",
) -> AnalyticsSummaryResponse:
    return analytics_service.summary(
        db, current_user.id, period, from_date, to_date, time_zone
    )


@router.get("/intensity", response_model=AnalyticsIntensityResponse)
def get_intensity_chart(
    db: DbSession,
    current_user: CurrentUser,
    period: Annotated[PeriodEnum, Query()] = PeriodEnum.month,
    from_date: Annotated[date | None, Query()] = None,
    to_date: Annotated[date | None, Query()] = None,
    time_zone: Annotated[str, Query(max_length=64)] = "UTC",
) -> AnalyticsIntensityResponse:
    return analytics_service.intensity(
        db, current_user.id, period, from_date, to_date, time_zone
    )


@router.get("/triggers", response_model=AnalyticsTriggersResponse)
def get_analytics_triggers(current_user: CurrentUser) -> AnalyticsTriggersResponse:
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Корреляционный анализ триггеров будет добавлен после накопления достаточного объёма данных.",
    )


@router.get("/export")
def export_analytics(
    db: DbSession,
    current_user: CurrentUser,
    format: Annotated[ExportFormatEnum, Query()],
    from_date: Annotated[date | None, Query()] = None,
    to_date: Annotated[date | None, Query()] = None,
) -> Response:
    if format == ExportFormatEnum.pdf:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="PDF-экспорт пока не реализован. Используйте format=csv.",
        )
    content = analytics_service.export_csv(db, current_user.id, from_date, to_date)
    return Response(
        content=content,
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": "attachment; filename=report.csv"},
    )
