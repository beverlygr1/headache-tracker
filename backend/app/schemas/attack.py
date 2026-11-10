from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.types import ensure_utc

MedicationEffect = Literal["helped", "partly", "not_helped"]


class AttackCreateRequest(BaseModel):
    client_request_id: UUID | None = None
    start_time: datetime
    intensity: int = Field(..., ge=1, le=10)
    pain_type: str | None = Field(None, max_length=80)
    localization: str | None = Field(None, max_length=120)
    medications: list[str] | None = None
    symptoms: list[str] | None = None
    relief_factors: list[str] | None = None
    medication_effects: dict[str, MedicationEffect] = Field(default_factory=dict, max_length=100)

    @model_validator(mode="after")
    def validate_effects(self):
        if not set(self.medication_effects).issubset(self.medications or []):
            raise ValueError("Результат можно указать только для выбранного препарата")
        return self

    @field_validator("start_time")
    @classmethod
    def normalize_start_time(cls, value: datetime) -> datetime:
        return ensure_utc(value)


class AttackUpdateRequest(BaseModel):
    start_time: datetime | None = None
    end_time: datetime | None = None
    intensity: int | None = Field(None, ge=1, le=10)
    pain_type: str | None = Field(None, max_length=80)
    localization: str | None = Field(None, max_length=120)
    medications: list[str] | None = None
    symptoms: list[str] | None = None
    relief_factors: list[str] | None = None
    medication_effects: dict[str, MedicationEffect] = Field(default_factory=dict, max_length=100)

    @field_validator("start_time", "end_time")
    @classmethod
    def normalize_times(cls, value: datetime | None) -> datetime | None:
        return ensure_utc(value) if value is not None else None


class AttackResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    start_time: datetime
    end_time: datetime | None = None
    intensity: int
    pain_type: str | None = None
    localization: str | None = None
    medications: list[str] | None = None
    symptoms: list[str] | None = None
    relief_factors: list[str] | None = None
    medication_effects: dict[str, MedicationEffect] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_times(self):
        if self.end_time is not None and self.end_time < self.start_time:
            raise ValueError("end_time не может быть раньше start_time")
        return self
