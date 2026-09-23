from datetime import datetime, timezone

from sqlalchemy import DateTime
from sqlalchemy.types import TypeDecorator


def ensure_utc(value: datetime) -> datetime:
    """Naive datetime считается UTC; aware приводится к UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class UTCDateTime(TypeDecorator):
    """DateTime(timezone=True), который всегда пишет и возвращает aware-UTC.

    PostgreSQL сам хранит timestamptz, но SQLite теряет tzinfo — без этого
    сравнение naive/aware datetime падает с TypeError.
    """

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect) -> datetime | None:
        return ensure_utc(value) if value is not None else None

    def process_result_value(self, value: datetime | None, dialect) -> datetime | None:
        return ensure_utc(value) if value is not None else None
