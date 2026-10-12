from datetime import date, timedelta

import pytest

from app.ml.features import DiaryValues, build_features
from app.ml.prediction_schemas import FEATURE_COLS, PredictionInput

TODAY = date(2026, 10, 12)


def d(days_ago: int) -> date:
    return TODAY - timedelta(days=days_ago)


def entry(days_ago: int, **kw) -> DiaryValues:
    return DiaryValues(date=d(days_ago), **kw)


@pytest.mark.parametrize("stress,expected", [(6, 0), (7, 1), (10, 1)])
def test_stress_threshold(stress, expected):
    f = build_features([entry(0, stress_level=stress)], [], TODAY)
    assert f["stress"] == expected


@pytest.mark.parametrize(
    "hours,lack,excess",
    [(5.9, 1, 0), (6, 0, 0), (10, 0, 0), (10.1, 0, 1)],
)
def test_sleep_thresholds(hours, lack, excess):
    f = build_features([entry(0, sleep_hours=hours)], [], TODAY)
    assert (f["lack_of_sleep"], f["excess_sleep"]) == (lack, excess)


@pytest.mark.parametrize("mg,expected", [(400, 0), (401, 1)])
def test_caffeine_threshold(mg, expected):
    f = build_features([entry(0, caffeine_intake=mg)], [], TODAY)
    assert f["excessive_caffeine"] == expected


def test_null_fields_are_not_passed():
    f = build_features([entry(0)], [], TODAY)
    assert set(f) == {"days_since_last_attack", "attacks_last_7_records"}


def test_no_entry_today_record_features_not_passed():
    f = build_features([entry(1, stress_level=9, sleep_hours=4, caffeine_intake=900)], [], TODAY)
    assert set(f) == {"days_since_last_attack", "attacks_last_7_records"}


def test_attack_today_in_current_record():
    f = build_features([entry(1), entry(0)], [d(0)], TODAY)
    assert f["days_since_last_attack"] == 0
    assert f["attacks_last_7_records"] == 0


def test_attack_in_old_record():
    entries = [entry(i) for i in (4, 3, 2, 1, 0)]
    f = build_features(entries, [d(3)], TODAY)
    assert f["days_since_last_attack"] == 3
    assert f["attacks_last_7_records"] == 1


def test_no_attacks_count_from_first_record():
    entries = [entry(i) for i in (3, 2, 1, 0)]
    f = build_features(entries, [], TODAY)
    assert f["days_since_last_attack"] == 3
    assert f["attacks_last_7_records"] == 0


def test_counts_records_not_calendar_days():
    entries = [entry(10), entry(5), entry(0)]
    f = build_features(entries, [d(10)], TODAY)
    assert f["days_since_last_attack"] == 2


def test_fewer_than_seven_previous_records():
    f = build_features([entry(1), entry(0)], [d(1)], TODAY)
    assert f["attacks_last_7_records"] == 1


def test_window_is_exactly_seven_previous_records():
    entries = [entry(i) for i in range(9, -1, -1)]
    f = build_features(entries, [d(9), d(2)], TODAY)
    assert f["attacks_last_7_records"] == 1


def test_two_attacks_same_day_count_twice():
    entries = [entry(2), entry(1), entry(0)]
    f = build_features(entries, [d(1), d(1)], TODAY)
    assert f["attacks_last_7_records"] == 2


def test_attacks_count_capped_at_seven():
    entries = [entry(i) for i in (2, 1, 0)]
    f = build_features(entries, [d(1)] * 12, TODAY)
    assert f["attacks_last_7_records"] == 7
    PredictionInput(**f)


def test_attack_on_date_without_diary_entry_ignored():
    f = build_features([entry(3), entry(0)], [d(1)], TODAY)
    assert f["days_since_last_attack"] == 1
    assert f["attacks_last_7_records"] == 0


def test_attack_today_without_diary_entry_counts_for_today():
    f = build_features([entry(2)], [d(0)], TODAY)
    assert f["days_since_last_attack"] == 0


def test_future_entries_ignored():
    future = DiaryValues(date=TODAY + timedelta(days=1), stress_level=10)
    f = build_features([future, entry(0)], [], TODAY)
    assert f["days_since_last_attack"] == 0


def test_no_data_at_all():
    assert build_features([], [], TODAY) == {
        "days_since_last_attack": 0,
        "attacks_last_7_records": 0,
    }


def test_features_are_valid_model_input():
    f = build_features(
        [entry(1), entry(0, stress_level=8, sleep_hours=5, caffeine_intake=500)],
        [d(1)],
        TODAY,
    )
    assert set(f) <= set(FEATURE_COLS)
    PredictionInput(**f)


def test_real_model_smoke():
    from app.ml.predictor import load_model

    f = build_features(
        [entry(1), entry(0, stress_level=8, sleep_hours=5, caffeine_intake=500)],
        [d(1)],
        TODAY,
    )
    p = load_model().predict(PredictionInput(**f))
    assert 0.0 <= p <= 1.0
