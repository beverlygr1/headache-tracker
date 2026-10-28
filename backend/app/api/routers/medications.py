from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.new_features import UserMedication
from app.schemas.new_features import MedicationCreate, MedicationResponse

router = APIRouter(prefix="/medications", tags=["Аптечка и препараты"])


# Names for recording only: no dosage or treatment recommendations.
CATALOG = ("Ибупрофен", "Парацетамол", "Суматриптан", "Нурофен", "Миг 400", "Аспирин", "Пенталгин", "Солпадеин")


@router.get("/catalog", response_model=list[str])
def medication_catalog(query: str = Query(default="", max_length=120), current_user=Depends(get_current_user), db: Session = Depends(get_db)):
    personal = db.scalars(select(UserMedication.name).where(UserMedication.user_id == current_user.id).order_by(UserMedication.id)).all()
    result = []
    seen = set()
    needle = query.strip().casefold()
    for name in [*personal, *CATALOG]:
        key = name.casefold()
        if key not in seen and needle in key:
            seen.add(key)
            result.append(name)
    return result


@router.get("", response_model=List[MedicationResponse])
def get_user_medications(
        current_user=Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Получение списка сохранённых препаратов с их эффективностью."""
    stmt = select(UserMedication).where(UserMedication.user_id == current_user.id)
    result = db.execute(stmt)
    return result.scalars().all()


@router.post("", response_model=MedicationResponse, status_code=status.HTTP_201_CREATED)
def add_medication(
        data: MedicationCreate,
        current_user=Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Добавление нового препарата в аптечку."""
    saved = db.scalars(select(UserMedication).where(UserMedication.user_id == current_user.id)).all()
    for item in saved:
        if item.name.casefold() == data.name.casefold() and item.dosage == data.dosage:
            return item
    med = UserMedication(
        user_id=current_user.id,
        name=data.name,
        dosage=data.dosage
    )
    db.add(med)
    db.commit()
    db.refresh(med)
    return med


@router.delete("/{id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_medication(
        id: int,
        current_user=Depends(get_current_user),
        db: Session = Depends(get_db)
):
    """Удаление препарата из аптечки."""
    stmt = select(UserMedication).where(UserMedication.id == id, UserMedication.user_id == current_user.id)
    result = db.execute(stmt)
    med = result.scalar_one_or_none()

    if not med:
        raise HTTPException(status_code=404, detail="Препарат не найден")

    db.delete(med)
    db.commit()
    return None