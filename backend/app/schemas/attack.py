from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.types import ensure_utc


class AttackCreateRequest(BaseModel):
    start_time: datetime
    intensity: int = Field(..., ge=1, le=10)
    pain_type: str | None = Field(None, max_length=80)
    localization: str | None = Field(None, max_length=120)
    medications: list[str] | None = None

    @field_validator("start_time")
    @classmethod
    def normalize_start_time(cls, value: datetime) -> datetime:
        return ensure_utc(value)


class AttackUpdateRequest(BaseModel):
    end_time: datetime | None = None
    intensity: int | None = Field(None, ge=1, le=10)
    pain_type: str | None = Field(None, max_length=80)
    localization: str | None = Field(None, max_length=120)
    medications: list[str] | None = None
    symptoms: list[str] | None = None
    relief_factors: list[str] | None = None

    @field_validator("end_time")
    @classmethod
    def normalize_end_time(cls, value: datetime | None) -> datetime | None:
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

    @model_validator(mode="after")
    def validate_times(self):
        if self.end_time is not None and self.end_time < self.start_time:
            raise ValueError("end_time не может быть раньше start_time")
        return self
