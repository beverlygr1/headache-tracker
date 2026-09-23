from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.diary import DiaryEntry


def get_entry(db: Session, user_id: int, entry_date: date) -> DiaryEntry | None:
    return db.execute(
        select(DiaryEntry).where(DiaryEntry.user_id == user_id, DiaryEntry.date == entry_date)
    ).scalar_one_or_none()


def upsert_entry(db: Session, user_id: int, entry_date: date, values: dict) -> DiaryEntry:
    entry = get_entry(db, user_id, entry_date)
    if entry is None:
        entry = DiaryEntry(user_id=user_id, date=entry_date, **values)
        db.add(entry)
    else:
        for field, value in values.items():
            setattr(entry, field, value)
    db.commit()
    db.refresh(entry)
    return entry


def list_entries(db: Session, user_id: int, from_date: date | None, to_date: date | None) -> list[DiaryEntry]:
    stmt = select(DiaryEntry).where(DiaryEntry.user_id == user_id)
    if from_date is not None:
        stmt = stmt.where(DiaryEntry.date >= from_date)
    if to_date is not None:
        stmt = stmt.where(DiaryEntry.date <= to_date)
    result = db.execute(stmt.order_by(DiaryEntry.date.desc()))
    return list(result.scalars().all())
