from datetime import date, datetime, time, timedelta, timezone
import hashlib
import json

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.attack import Attack


def _day_start(value: date) -> datetime:
    return datetime.combine(value, time.min, tzinfo=timezone.utc)


def _next_day_start(value: date) -> datetime:
    return _day_start(value + timedelta(days=1))


def create_attack(db: Session, user_id: int, values: dict) -> Attack:
    request_id = values.get("client_request_id")
    if request_id is not None:
        values = dict(values, client_request_id=str(request_id))
        fingerprint = hashlib.sha256(json.dumps(
            {k: v for k, v in values.items() if k != "client_request_id"},
            sort_keys=True, ensure_ascii=False, default=str,
        ).encode()).hexdigest()
        values["client_payload_hash"] = fingerprint

        def existing_request():
            existing = db.scalar(select(Attack).where(
                Attack.user_id == user_id, Attack.client_request_id == str(request_id)
            ))
            if existing is not None and existing.client_payload_hash != fingerprint:
                raise HTTPException(status_code=409, detail="Этот идентификатор уже использован для другой записи")
            return existing

        existing = existing_request()
        if existing is not None:
            return existing
    attack = Attack(user_id=user_id, **values)
    db.add(attack)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        if request_id is not None:
            existing = existing_request()
            if existing is not None:
                return existing
        raise
    db.refresh(attack)
    return attack


def get_attack(db: Session, user_id: int, attack_id: int) -> Attack | None:
    return db.execute(
        select(Attack).where(Attack.id == attack_id, Attack.user_id == user_id)
    ).scalar_one_or_none()


def list_attacks(
    db: Session,
    user_id: int,
    from_date: date | None,
    to_date: date | None,
    limit: int,
    offset: int,
) -> list[Attack]:
    stmt = select(Attack).where(Attack.user_id == user_id)
    if from_date is not None:
        stmt = stmt.where(Attack.start_time >= _day_start(from_date))
    if to_date is not None:
        stmt = stmt.where(Attack.start_time < _next_day_start(to_date))
    result = db.execute(
        stmt.order_by(Attack.start_time.desc()).limit(limit).offset(offset)
    )
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


def list_start_times(
    db: Session, user_id: int, *, until: datetime | None = None
) -> list[datetime]:
    stmt = select(Attack.start_time).where(Attack.user_id == user_id)
    if until is not None:
        stmt = stmt.where(Attack.start_time <= until)
    return list(db.execute(stmt).scalars().all())
