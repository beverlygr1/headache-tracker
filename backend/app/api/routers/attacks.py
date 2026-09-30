from datetime import date

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.api.deps import CurrentUser, DbSession
from app.repositories import attacks as attack_repo
from app.schemas.attack import AttackCreateRequest, AttackResponse, AttackUpdateRequest

router = APIRouter(prefix="/attacks", tags=["Приступы"])


@router.post("", response_model=AttackResponse, status_code=status.HTTP_201_CREATED)
def create_attack(data: AttackCreateRequest, db: DbSession, current_user: CurrentUser) -> AttackResponse:
    return AttackResponse.model_validate(attack_repo.create_attack(db, current_user.id, data.model_dump()))


@router.get("", response_model=list[AttackResponse])
def get_attacks(db: DbSession, current_user: CurrentUser, from_date: date | None = Query(None), to_date: date | None = Query(None), limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0)) -> list[AttackResponse]:
    return [AttackResponse.model_validate(item) for item in attack_repo.list_attacks(db, current_user.id, from_date, to_date, limit, offset)]


@router.get("/{attack_id}", response_model=AttackResponse)
def get_attack_by_id(attack_id: int, db: DbSession, current_user: CurrentUser) -> AttackResponse:
    attack = attack_repo.get_attack(db, current_user.id, attack_id)
    if attack is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Приступ не найден")
    return AttackResponse.model_validate(attack)


@router.put("/{attack_id}", response_model=AttackResponse)
def update_attack(attack_id: int, data: AttackUpdateRequest, db: DbSession, current_user: CurrentUser) -> AttackResponse:
    attack = attack_repo.get_attack(db, current_user.id, attack_id)
    if attack is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Приступ не найден")
    values = data.model_dump(exclude_unset=True)
    start_time = values.get("start_time", attack.start_time)
    if start_time is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="start_time не может быть пустым")
    end_time = values.get("end_time", attack.end_time)
    if end_time is not None and end_time < start_time:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="end_time не может быть раньше start_time")
    return AttackResponse.model_validate(attack_repo.update_attack(db, attack, values))


@router.delete("/{attack_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_attack(attack_id: int, db: DbSession, current_user: CurrentUser) -> Response:
    attack = attack_repo.get_attack(db, current_user.id, attack_id)
    if attack is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Приступ не найден")
    attack_repo.delete_attack(db, attack)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
