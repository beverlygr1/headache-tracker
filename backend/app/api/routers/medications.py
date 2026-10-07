from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.new_features import UserMedication
from app.schemas.new_features import MedicationCreate, MedicationResponse

router = APIRouter(prefix="/medications", tags=["Аптечка и препараты"])


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