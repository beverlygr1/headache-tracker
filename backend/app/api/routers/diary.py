from datetime import date

from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import CurrentUser, DbSession
from app.repositories import diary as diary_repo
from app.schemas.diary import DiaryResponse, DiaryUpsertRequest

router = APIRouter(prefix="/diary", tags=["Дневник факторов"])


@router.put("/{date_str}", response_model=DiaryResponse)
def upsert_diary_entry(date_str: date, data: DiaryUpsertRequest, db: DbSession, current_user: CurrentUser) -> DiaryResponse:
    return DiaryResponse.model_validate(diary_repo.upsert_entry(db, current_user.id, date_str, data.model_dump(exclude_unset=True)))


@router.get("/{date_str}", response_model=DiaryResponse)
def get_diary_by_date(date_str: date, db: DbSession, current_user: CurrentUser) -> DiaryResponse:
    entry = diary_repo.get_entry(db, current_user.id, date_str)
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Запись дневника не найдена")
    return DiaryResponse.model_validate(entry)


@router.get("", response_model=list[DiaryResponse])
def get_diary_entries(db: DbSession, current_user: CurrentUser, from_date: date | None = Query(None), to_date: date | None = Query(None)) -> list[DiaryResponse]:
    return [DiaryResponse.model_validate(entry) for entry in diary_repo.list_entries(db, current_user.id, from_date, to_date)]
