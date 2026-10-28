from datetime import date

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class UserProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: EmailStr
    name: str
    time_zone: str | None = None
    gender: str | None = None
    birth_date: date | None = None
    onboarding_step: int = 0
    onboarding_completed: bool = False


class UserProfileUpdateRequest(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=120)
    time_zone: str | None = Field(None, max_length=64)
    gender: str | None = Field(None, max_length=32)
    birth_date: date | None = None


    @field_validator("name")
    @classmethod
    def valid_name(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("Укажите имя")
        value = value.strip()
        if not value:
            raise ValueError("Укажите имя")
        return value


class OnboardingUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    step: int = Field(ge=0, le=1, strict=True)
    completed: bool = Field(default=False, strict=True)
