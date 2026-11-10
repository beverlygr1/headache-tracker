import datetime

from pydantic import BaseModel, Field


class WeatherDetails(BaseModel):
    delta_pressure_hpa: float = Field(description="|среднее давление (мор. уровень) сегодня − вчера|, гПа.")
    delta_temperature_c: float = Field(description="|средняя температура сегодня − вчера|, °C.")
    pressure_level: int = Field(ge=0, le=2, description="Уровень изменения по давлению: 0/1/2.")
    temperature_level: int = Field(ge=0, le=2, description="Уровень изменения по температуре: 0/1/2.")


class WeatherChangeResponse(BaseModel):
    weather_change: int = Field(
        ge=0,
        le=2,
        description="0 — незначительное, 1 — среднее, 2 — значительное изменение погоды.",
    )
    label: str = Field(description="minor / moderate / significant.")
    date: datetime.date = Field(description="Локальная дата точки (сегодня).")
    timezone: str = Field(description="Часовой пояс точки, определённый Open-Meteo.")
    details: WeatherDetails
    source: str
    record_id: int = Field(description="id записи в weather_observations.")
