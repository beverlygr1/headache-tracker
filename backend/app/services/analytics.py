import csv
import io
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.attack import Attack
from app.schemas.analytics import AnalyticsSummaryResponse, PeriodEnum


def _period_start(period: PeriodEnum) -> datetime:
    now = datetime.now(timezone.utc)
    if period == PeriodEnum.week:
        return now - timedelta(days=7)
    if period == PeriodEnum.year:
        return now - timedelta(days=365)
    return now - timedelta(days=30)


def summary(db: Session, user_id: int, period: PeriodEnum) -> AnalyticsSummaryResponse:
    attacks = list(db.execute(
        select(Attack).where(Attack.user_id == user_id, Attack.start_time >= _period_start(period))
    ).scalars().all())
    if not attacks:
        return AnalyticsSummaryResponse(period=period, total_attacks=0, avg_intensity=0.0, avg_duration_minutes=0.0)
    avg_intensity = sum(item.intensity for item in attacks) / len(attacks)
    durations = [(item.end_time - item.start_time).total_seconds() / 60 for item in attacks if item.end_time is not None and item.end_time >= item.start_time]
    avg_duration = sum(durations) / len(durations) if durations else 0.0
    return AnalyticsSummaryResponse(period=period, total_attacks=len(attacks), avg_intensity=round(avg_intensity, 2), avg_duration_minutes=round(avg_duration, 2))


def export_csv(db: Session, user_id: int, from_date: date | None = None, to_date: date | None = None) -> str:
    stmt = select(Attack).where(Attack.user_id == user_id)
    if from_date is not None:
        stmt = stmt.where(Attack.start_time >= datetime.combine(from_date, datetime.min.time(), tzinfo=timezone.utc))
    if to_date is not None:
        stmt = stmt.where(Attack.start_time < datetime.combine(to_date + timedelta(days=1), datetime.min.time(), tzinfo=timezone.utc))
    attacks = list(db.execute(stmt.order_by(Attack.start_time.desc())).scalars().all())
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["id", "start_time", "end_time", "intensity", "pain_type", "localization"])
    for attack in attacks:
        writer.writerow([attack.id, attack.start_time.isoformat(), attack.end_time.isoformat() if attack.end_time else "", attack.intensity, attack.pain_type or "", attack.localization or ""])
    return output.getvalue()
