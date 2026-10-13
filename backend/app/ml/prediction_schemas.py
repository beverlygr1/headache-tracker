"""Автогенерировано из ноутбука headache_next_day_model.ipynb — не править руками.

Схема входных данных эндпоинта предсказания приступа головной боли на следующий день.
Любой непереданный признак равен 0.
"""
from typing import List

import pandas as pd
from pydantic import BaseModel, ConfigDict, Field

FEATURE_COLS: List[str] = [
    "stress",
    "excess_sleep",
    "lack_of_sleep",
    "exercise_trigger",
    "no_exercise_trigger",
    "physical_fatigue",
    "menstrual_phase",
    "ovulation_phase",
    "excessive_emotional_change",
    "weather_change",
    "excessive_sunlight",
    "noise",
    "poor_lighting",
    "specific_smell",
    "excessive_alcohol",
    "irregular_meals",
    "overeating",
    "excessive_caffeine",
    "excessive_smoking",
    "cheese_chocolate",
    "travel",
    "other_trigger",
    "days_since_last_attack",
    "attacks_last_7_records"
]


class PredictionInput(BaseModel):
    model_config = ConfigDict(extra='forbid')

    stress: int = Field(default=0, ge=0, le=1, description="В этот день пациент отметил стресс.")
    excess_sleep: int = Field(default=0, ge=0, le=1, description="Пересып: пациент спал больше обычного.")
    lack_of_sleep: int = Field(default=0, ge=0, le=1, description="Недосып: пациент спал меньше обычного.")
    exercise_trigger: int = Field(default=0, ge=0, le=1, description="Физическая нагрузка / тренировка в этот день отмечена пациентом как возможный триггер.")
    no_exercise_trigger: int = Field(default=0, ge=0, le=1, description="Отсутствие / недостаток физической активности отмечен пациентом как возможный триггер.")
    physical_fatigue: int = Field(default=0, ge=0, le=1, description="Физическая усталость, переутомление.")
    menstrual_phase: int = Field(default=0, ge=0, le=1, description="День приходится на менструальную фазу цикла.")
    ovulation_phase: int = Field(default=0, ge=0, le=1, description="День приходится на овуляторную фазу цикла.")
    excessive_emotional_change: int = Field(default=0, ge=0, le=1, description="Сильные эмоциональные перепады в этот день.")
    weather_change: int = Field(default=0, ge=0, le=1, description="Резкая смена погоды в этот день.")
    excessive_sunlight: int = Field(default=0, ge=0, le=1, description="Избыток яркого солнечного света.")
    noise: int = Field(default=0, ge=0, le=1, description="Сильный или раздражающий шум.")
    poor_lighting: int = Field(default=0, ge=0, le=1, description="Неблагоприятное освещение.")
    specific_smell: int = Field(default=0, ge=0, le=1, description="Воздействие резких или специфических запахов.")
    excessive_alcohol: int = Field(default=0, ge=0, le=1, description="Чрезмерное употребление алкоголя.")
    irregular_meals: int = Field(default=0, ge=0, le=1, description="Нерегулярное питание, пропуск приёмов пищи.")
    overeating: int = Field(default=0, ge=0, le=1, description="Переедание.")
    excessive_caffeine: int = Field(default=0, ge=0, le=1, description="Чрезмерное потребление кофеина.")
    excessive_smoking: int = Field(default=0, ge=0, le=1, description="Чрезмерное курение.")
    cheese_chocolate: int = Field(default=0, ge=0, le=1, description="Употребление сыра / шоколада.")
    travel: int = Field(default=0, ge=0, le=1, description="Поездка, путешествие в этот день.")
    other_trigger: int = Field(default=0, ge=0, le=1, description="Другой триггер, не вошедший в список выше.")
    days_since_last_attack: int = Field(default=0, ge=0, description="Сколько записей дневника прошло с последнего приступа. 0 — приступ был именно в этот день; 1 — вчера и т.д. Если приступов у пациента ещё не было, счёт идёт с первой записи. ВНИМАНИЕ: считается в записях, а не в календарных днях. Значение по умолчанию 0 в API означает «приступ сегодня».")
    attacks_last_7_records: int = Field(default=0, ge=0, le=7, description="Число приступов за предыдущие 7 записей дневника (текущий день НЕ входит). Диапазон 0–7.")

    def to_dataframe(self) -> pd.DataFrame:
        """Одна строка с колонками в том же порядке, в каком модель обучалась."""
        data = self.model_dump()
        return pd.DataFrame([[data[c] for c in FEATURE_COLS]], columns=FEATURE_COLS)
