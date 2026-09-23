from datetime import date, datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.attack import Attack


def _day_start(value: date) -> datetime:
    return datetime.combine(value, time.min, tzinfo=timezone.utc)


def _next_day_start(value: date) -> datetime:
    return _day_start(value + timedelta(days=1))


def create_attack(db: Session, user_id: int, values: dict) -> Attack:
    attack = Attack(user_id=user_id, **values)
    db.add(attack)
    db.commit()
    db.refresh(attack)
    return attack


def get_attack(db: Session, user_id: int, attack_id: int) -> Attack | None:
    return db.execute(
        select(Attack).where(Attack.id == attack_id, Attack.user_id == user_id)
    ).scalar_one_or_none()


def list_attacks(db: Session, user_id: int, from_date: date | None, to_date: date | None, limit: int, offset: int) -> list[Attack]:
    stmt = select(Attack).where(Attack.user_id == user_id)
    if from_date is not None:
        stmt = stmt.where(Attack.start_time >= _day_start(from_date))
    if to_date is not None:
        stmt = stmt.where(Attack.start_time < _next_day_start(to_date))
    result = db.execute(stmt.order_by(Attack.start_time.desc()).limit(limit).offset(offset))
    return list(result.scalars().all())


def update_attack(db: Session, attack: Attack, values: dict) -> Attack:
    for field, value in values.items():
        setattr(attack, field, value)
    db.commit()
    db.refresh(attack)
    return attack


def delete_attack(db: Session, attack: Attack) -> None:
    db.delete(attack)
    db.commit()
