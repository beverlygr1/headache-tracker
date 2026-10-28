from typing import Optional, List
from pydantic import BaseModel, ConfigDict, Field, field_validator


# --- Аптечка ---
class MedicationCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120, description="Название препарата")
    dosage: str = Field(default="", max_length=50, description="Дозировка, если указана пользователем")


    @field_validator("name")
    @classmethod
    def valid_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Укажите название препарата")
        return value


class MedicationResponse(BaseModel):
    id: int
    user_id: int
    name: str
    dosage: str
    usage_count: int = 0
    effectiveness_pct: float = 0.0

    model_config = ConfigDict(from_attributes=True)


# --- Настройки профиля ---
class UserSettingsUpdate(BaseModel):
    work_schedule: Optional[str] = Field(None, description="График работы: '5/2', '2/2', '7/0'")
    daily_reminder_enabled: Optional[bool] = True
    daily_reminder_time: Optional[str] = Field("20:00", description="Формат HH:MM")
    risk_alert_enabled: Optional[bool] = True
    medication_reminder_enabled: Optional[bool] = True
    medication_reminder_time: Optional[str] = Field("08:00", description="Формат HH:MM")
    theme: Optional[str] = Field("dark", description="'light' или 'dark'")


class UserSettingsResponse(UserSettingsUpdate):
    user_id: int

    model_config = ConfigDict(from_attributes=True)


# --- Профилактика и База знаний ---
class SupplementCreate(BaseModel):
    name: str = Field(..., max_length=120, description="Название (например, 'Магний B6')")
    intake_time: str = Field(..., description="Время приёма (например, '09:00')")


class SupplementResponse(BaseModel):
    id: int
    user_id: int
    name: str
    intake_time: str

    model_config = ConfigDict(from_attributes=True)


class ArticleResponse(BaseModel):
    id: str
    title: str
    category: str
    summary: str
    content: str