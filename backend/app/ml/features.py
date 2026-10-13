from collections import Counter
from dataclasses import dataclass
from datetime import date

STRESS_HIGH = 7
SLEEP_LACK_HOURS = 6
SLEEP_EXCESS_HOURS = 10
CAFFEINE_EXCESS_MG = 400
LAST_RECORDS = 7


@dataclass(frozen=True)
class DiaryValues:
    date: date
    sleep_hours: float | None = None
    stress_level: int | None = None
    caffeine_intake: int | None = None


def build_features(
    entries: list[DiaryValues],
    attack_dates: list[date],
    today: date,
) -> dict[str, int]:
    past = sorted((e for e in entries if e.date <= today), key=lambda e: e.date)
    today_entry = past[-1] if past and past[-1].date == today else None
    if today_entry is not None:
        past = past[:-1]

    record_dates = [e.date for e in past] + [today]
    cur = len(record_dates) - 1
    attacks_per_date = Counter(attack_dates)

    features: dict[str, int] = {}

    if today_entry is not None:
        if today_entry.stress_level is not None:
            features["stress"] = int(today_entry.stress_level >= STRESS_HIGH)
        if today_entry.sleep_hours is not None:
            features["lack_of_sleep"] = int(today_entry.sleep_hours < SLEEP_LACK_HOURS)
            features["excess_sleep"] = int(today_entry.sleep_hours > SLEEP_EXCESS_HOURS)
        if today_entry.caffeine_intake is not None:
            features["excessive_caffeine"] = int(
                today_entry.caffeine_intake > CAFFEINE_EXCESS_MG
            )

    days_since = cur
    for k in range(cur, -1, -1):
        if attacks_per_date[record_dates[k]] > 0:
            days_since = cur - k
            break
    features["days_since_last_attack"] = days_since

    previous = record_dates[max(0, cur - LAST_RECORDS) : cur]
    features["attacks_last_7_records"] = min(
        sum(attacks_per_date[d] for d in previous), LAST_RECORDS
    )
    return features
