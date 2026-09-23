from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class DiaryUpsertRequest(BaseModel):
    sleep_hours: float | None = Field(None, ge=0, le=24)
    sleep_quality: int | None = Field(None, ge=1, le=10)
    stress_level: int | None = Field(None, ge=1, le=10)
    caffeine_intake: int | None = Field(None, ge=0)
    water_ml: int | None = Field(None, ge=0)
    latitude: float | None = Field(None, ge=-90, le=90)
    longitude: float | None = Field(None, ge=-180, le=180)


class DiaryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: date
    sleep_hours: float | None = None
    sleep_quality: int | None = None
    stress_level: int | None = None
    caffeine_intake: int | None = None
    water_ml: int | None = None
    latitude: float | None = None
    longitude: float | None = None
