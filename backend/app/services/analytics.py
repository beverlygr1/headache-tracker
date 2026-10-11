import csv
import io
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.date_ranges import validate_date_range
from app.models.attack import Attack
from app.models.diary import DiaryEntry
from app.schemas.analytics import (
    AnalyticsIntensityResponse,
    AnalyticsSummaryResponse,
    IntensityPoint,
    PeriodEnum,
)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _zone(name: str) -> ZoneInfo:
    try:
        return ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError):
        raise HTTPException(
            status_code=422,
            detail="time_zone должен быть часовым поясом IANA, например Asia/Tomsk",
        ) from None


@dataclass(frozen=True)
class AnalyticsWindow:
    from_date: date
    to_date: date
    zone: ZoneInfo
    start: datetime
    end: datetime
    now: datetime


def _window(
    period: PeriodEnum, from_date: date | None, to_date: date | None, time_zone: str
) -> AnalyticsWindow:
    zone = _zone(time_zone)
    now = _now()
    if (from_date is None) != (to_date is None):
        raise HTTPException(
            status_code=422,
            detail="Для своего периода передайте обе даты: from_date и to_date",
        )
    if from_date is None:
        to_date = now.astimezone(zone).date()
        days = {PeriodEnum.week: 7, PeriodEnum.month: 30, PeriodEnum.year: 365}[period]
        from_date = to_date - timedelta(days=days - 1)
    validate_date_range(from_date, to_date)
    if (to_date - from_date).days >= 366:
        raise HTTPException(
            status_code=422, detail="Период не должен превышать 366 дней"
        )
    try:
        start = datetime.combine(from_date, time.min, tzinfo=zone).astimezone(
            timezone.utc
        )
        end = datetime.combine(
            to_date + timedelta(days=1), time.min, tzinfo=zone
        ).astimezone(timezone.utc)
    except (OverflowError, ValueError):
        raise HTTPException(
            status_code=422, detail="Дата выходит за поддерживаемые границы"
        ) from None
    # Future-dated observations never contribute to current statistics.
    return AnalyticsWindow(from_date, to_date, zone, start, min(end, now), now)


def _attacks(db: Session, user_id: int, window: AnalyticsWindow) -> list[Attack]:
    return list(
        db.execute(
            select(Attack)
            .where(
                Attack.user_id == user_id,
                Attack.start_time >= window.start,
                Attack.start_time < window.end,
            )
            .order_by(Attack.start_time, Attack.id)
        )
        .scalars()
        .all()
    )


def summary(
    db: Session,
    user_id: int,
    period: PeriodEnum,
    from_date: date | None = None,
    to_date: date | None = None,
    time_zone: str = "UTC",
) -> AnalyticsSummaryResponse:
    window = _window(period, from_date, to_date, time_zone)
    attacks = _attacks(db, user_id, window)
    # Active attacks have no known duration; future end times are not completed yet.
    durations = [
        (item.end_time - item.start_time).total_seconds() / 60
        for item in attacks
        if item.end_time is not None and item.start_time <= item.end_time <= window.now
    ]
    return AnalyticsSummaryResponse(
        period=period,
        total_attacks=len(attacks),
        avg_intensity=round(sum(item.intensity for item in attacks) / len(attacks), 2)
        if attacks
        else 0.0,
        avg_duration_minutes=round(sum(durations) / len(durations), 2)
        if durations
        else 0.0,
        completed_attacks=len(durations),
        from_date=window.from_date,
        to_date=window.to_date,
        time_zone=window.zone.key,
    )


def intensity(
    db: Session,
    user_id: int,
    period: PeriodEnum,
    from_date: date | None = None,
    to_date: date | None = None,
    time_zone: str = "UTC",
) -> AnalyticsIntensityResponse:
    window = _window(period, from_date, to_date, time_zone)
    by_day: dict[date, list[int]] = {}
    for attack in _attacks(db, user_id, window):
        day = attack.start_time.astimezone(window.zone).date()
        by_day.setdefault(day, []).append(attack.intensity)
    today = window.now.astimezone(window.zone).date()
    diaries = {
        entry.date: entry
        for entry in db.execute(
            select(DiaryEntry).where(
                DiaryEntry.user_id == user_id,
                DiaryEntry.date >= window.from_date,
                DiaryEntry.date <= min(window.to_date, today),
            )
        )
        .scalars()
        .all()
    }
    points = []
    for offset in range((window.to_date - window.from_date).days + 1):
        day = window.from_date + timedelta(days=offset)
        values = by_day.get(day, [])
        diary = diaries.get(day)
        points.append(
            IntensityPoint(
                date=day,
                total_attacks=len(values),
                avg_intensity=round(sum(values) / len(values), 2) if values else None,
                max_intensity=max(values) if values else None,
                diary_recorded=diary is not None,
                # Preserve the user's label rather than deriving it from absent attacks.
                headache_present=diary.headache_present if diary is not None else None,
            )
        )
    return AnalyticsIntensityResponse(
        period=period,
        from_date=window.from_date,
        to_date=window.to_date,
        time_zone=window.zone.key,
        points=points,
    )


def export_csv(
    db: Session,
    user_id: int,
    from_date: date | None = None,
    to_date: date | None = None,
) -> str:
    validate_date_range(from_date, to_date)
    stmt = select(Attack).where(Attack.user_id == user_id)
    if from_date is not None:
        stmt = stmt.where(
            Attack.start_time
            >= datetime.combine(from_date, datetime.min.time(), tzinfo=timezone.utc)
        )
    if to_date is not None:
        stmt = stmt.where(
            Attack.start_time
            < datetime.combine(
                to_date + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc
            )
        )
    attacks = list(db.execute(stmt.order_by(Attack.start_time.desc())).scalars().all())
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(
        ["id", "start_time", "end_time", "intensity", "pain_type", "localization"]
    )
    for attack in attacks:
        writer.writerow(
            [
                attack.id,
                attack.start_time.isoformat(),
                attack.end_time.isoformat() if attack.end_time else "",
                attack.intensity,
                attack.pain_type or "",
                attack.localization or "",
            ]
        )
    return output.getvalue()
