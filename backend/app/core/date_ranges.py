from datetime import date

from fastapi import HTTPException


def validate_date_range(from_date: date | None, to_date: date | None) -> None:
    if from_date is not None and to_date is not None and from_date > to_date:
        raise HTTPException(
            status_code=422, detail="from_date не может быть позже to_date"
        )
    # These dates cannot safely be converted to timezone-aware day boundaries.
    if from_date == date.min or to_date == date.max:
        raise HTTPException(
            status_code=422, detail="Дата выходит за поддерживаемые границы"
        )
