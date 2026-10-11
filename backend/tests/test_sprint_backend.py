from datetime import datetime, timezone

import pytest
from app.services import analytics


@pytest.fixture
def clock(monkeypatch):
    now = datetime(2026, 10, 11, 12, tzinfo=timezone.utc)
    monkeypatch.setattr(analytics, "_now", lambda: now)
    return now


def login(client, email="sprint@example.com"):
    assert (
        client.post(
            "/api/v1/auth/register",
            json={
                "email": email,
                "password": "password123",
                "name": "Sprint",
            },
        ).status_code
        == 201
    )
    response = client.post(
        "/api/v1/auth/login", json={"email": email, "password": "password123"}
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def attack(client, headers, start="2026-10-10T10:00:00Z", intensity=6, **extra):
    response = client.post(
        "/api/v1/attacks",
        headers=headers,
        json={
            "start_time": start,
            "intensity": intensity,
            **extra,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_extended_attack_survives_edit_finish_and_login(client):
    headers = login(client)
    fields = {
        "pain_type": "Пульсирующая",
        "localization": "Виски",
        "medications": ["Записанный пользователем препарат"],
        "symptoms": ["Тошнота"],
        "relief_factors": ["Отдых"],
    }
    record = attack(client, headers, **fields)
    path = f"/api/v1/attacks/{record['id']}"
    for key, value in fields.items():
        assert record[key] == value
    for update in ({"intensity": 4}, {"end_time": "2026-10-10T11:30:00Z"}):
        response = client.put(path, headers=headers, json=update)
        assert response.status_code == 200
        for key, value in fields.items():
            assert response.json()[key] == value
    tokens = client.post(
        "/api/v1/auth/login",
        json={"email": "sprint@example.com", "password": "password123"},
    ).json()
    fresh = {"Authorization": f"Bearer {tokens['access_token']}"}
    saved = client.get(path, headers=fresh).json()
    assert saved["intensity"] == 4
    assert saved["end_time"].startswith("2026-10-10T11:30:00")
    for key, value in fields.items():
        assert saved[key] == value
    cleared = client.put(
        path, headers=fresh, json={"medications": [], "pain_type": None}
    )
    assert cleared.status_code == 200
    assert cleared.json()["medications"] == []
    assert cleared.json()["pain_type"] is None
    assert cleared.json()["relief_factors"] == fields["relief_factors"]
    assert len(client.get("/api/v1/attacks", headers=fresh).json()) == 1


def test_invalid_attack_edit_leaves_record_unchanged(client):
    headers = login(client)
    record = attack(client, headers)
    path = f"/api/v1/attacks/{record['id']}"
    for payload in (
        {"intensity": None},
        {"intensity": 0},
        {"intensity": 11},
        {"end_time": "2026-10-10T09:59:00Z"},
        {"start_time": None},
    ):
        assert client.put(path, headers=headers, json=payload).status_code == 422
        assert client.get(path, headers=headers).json() == record


def test_headache_three_states_and_partial_diary_updates(client):
    headers = login(client)
    path = "/api/v1/diary/2026-10-10"
    original = {
        "sleep_hours": 7.5,
        "sleep_quality": 8,
        "caffeine_intake": 120,
        "stress_level": 4,
        "water_ml": 1800,
        "latitude": 56.5,
        "longitude": 84.9,
    }
    response = client.put(path, headers=headers, json=original)
    assert response.status_code == 200
    assert response.json()["headache_present"] is None
    for value in (True, False, None):
        response = client.put(path, headers=headers, json={"headache_present": value})
        assert response.status_code == 200
        assert response.json()["headache_present"] is value
        for key, expected in original.items():
            assert response.json()[key] == expected
        assert client.get(path, headers=headers).json()["headache_present"] is value
    client.put(path, headers=headers, json={"headache_present": True})
    response = client.put(path, headers=headers, json={"water_ml": None})
    assert response.json()["headache_present"] is True
    assert response.json()["water_ml"] is None
    assert len(client.get("/api/v1/diary", headers=headers).json()) == 1
    tokens = client.post(
        "/api/v1/auth/login",
        json={"email": "sprint@example.com", "password": "password123"},
    ).json()
    assert (
        client.get(
            path, headers={"Authorization": f"Bearer {tokens['access_token']}"}
        ).json()["headache_present"]
        is True
    )


@pytest.mark.parametrize("value", [0, 1, "true", "false", "", [], {}])
def test_headache_rejects_coercion(client, value):
    headers = login(client)
    assert (
        client.put(
            "/api/v1/diary/2026-10-10",
            headers=headers,
            json={"headache_present": value},
        ).status_code
        == 422
    )
    assert client.get("/api/v1/diary/2026-10-10", headers=headers).status_code == 404


def test_summary_and_chart_share_local_dates_and_do_not_invent_no_pain(client, clock):
    headers = login(client)
    # 17:00 UTC is the next calendar day in Tomsk. Midnight boundaries are inclusive/exclusive.
    attack(client, headers, "2026-10-08T16:59:59Z", 10)  # outside October 9-10
    first = attack(client, headers, "2026-10-08T17:00:00Z", 4)
    client.put(
        f"/api/v1/attacks/{first['id']}",
        headers=headers,
        json={"end_time": "2026-10-08T18:00:00Z"},
    )
    attack(client, headers, "2026-10-09T10:00:00Z", 8)  # active, no duration
    attack(client, headers, "2026-10-10T16:59:59Z", 9)
    attack(client, headers, "2026-10-10T17:00:00Z", 10)  # outside October 9-10
    client.put(
        "/api/v1/diary/2026-10-09", headers=headers, json={"headache_present": True}
    )
    params = {
        "from_date": "2026-10-09",
        "to_date": "2026-10-10",
        "time_zone": "Asia/Tomsk",
    }
    response = client.get("/api/v1/analytics/summary", headers=headers, params=params)
    assert response.status_code == 200, response.text
    summary = response.json()
    assert summary["total_attacks"] == 3
    assert summary["avg_intensity"] == 7.0
    assert summary["avg_duration_minutes"] == 60.0
    assert summary["completed_attacks"] == 1
    chart = client.get(
        "/api/v1/analytics/intensity", headers=headers, params=params
    ).json()
    for key in ("from_date", "to_date", "time_zone", "period"):
        assert chart[key] == summary[key]
    assert chart["points"] == [
        {
            "date": "2026-10-09",
            "total_attacks": 2,
            "avg_intensity": 6.0,
            "max_intensity": 8,
            "diary_recorded": True,
            "headache_present": True,
        },
        {
            "date": "2026-10-10",
            "total_attacks": 1,
            "avg_intensity": 9.0,
            "max_intensity": 9,
            "diary_recorded": False,
            "headache_present": None,
        },
    ]
    assert (
        sum(point["total_attacks"] for point in chart["points"])
        == summary["total_attacks"]
    )


def test_empty_days_and_explicit_no_pain_are_distinct(client, clock):
    headers = login(client)
    client.put(
        "/api/v1/diary/2026-10-09", headers=headers, json={"headache_present": False}
    )
    client.put("/api/v1/diary/2026-10-10", headers=headers, json={"sleep_hours": 8})
    params = {"from_date": "2026-10-08", "to_date": "2026-10-10"}
    points = client.get(
        "/api/v1/analytics/intensity", headers=headers, params=params
    ).json()["points"]
    assert [p["headache_present"] for p in points] == [None, False, None]
    assert [p["diary_recorded"] for p in points] == [False, True, True]
    assert all(
        p["avg_intensity"] is None and p["max_intensity"] is None for p in points
    )
    summary = client.get(
        "/api/v1/analytics/summary", headers=headers, params=params
    ).json()
    assert summary["total_attacks"] == 0
    assert summary["avg_intensity"] == 0
    assert summary["avg_duration_minutes"] == 0
    assert summary["completed_attacks"] == 0


@pytest.mark.parametrize(
    "period,days,start",
    [
        ("week", 7, "2026-10-05"),
        ("month", 30, "2026-09-12"),
        ("year", 365, "2025-10-12"),
    ],
)
def test_default_periods_and_future_observations(client, clock, period, days, start):
    headers = login(client)
    attack(client, headers, "2026-10-11T11:00:00Z", 2)
    attack(client, headers, "2026-10-11T13:00:00Z", 10)
    attack(client, headers, "2026-10-12T10:00:00Z", 10)
    response = client.get(
        "/api/v1/analytics/intensity", headers=headers, params={"period": period}
    )
    assert response.status_code == 200
    chart = response.json()
    assert chart["from_date"] == start
    assert chart["to_date"] == "2026-10-11"
    assert len(chart["points"]) == days
    assert sum(p["total_attacks"] for p in chart["points"]) == 1
    summary = client.get(
        "/api/v1/analytics/summary", headers=headers, params={"period": period}
    ).json()
    assert summary["total_attacks"] == 1
    assert summary["avg_intensity"] == 2
    assert summary["avg_duration_minutes"] == 0


@pytest.mark.parametrize(
    "params",
    [
        {"from_date": "2026-10-11"},
        {"to_date": "2026-10-11"},
        {"from_date": "2026-10-11", "to_date": "2026-10-10"},
        {"from_date": "2025-01-01", "to_date": "2026-10-11"},
        {"time_zone": "Not/AZone"},
        {"time_zone": "../UTC"},
        {"period": "day"},
        {"from_date": "0001-01-01", "to_date": "0001-01-02"},
        {"from_date": "9999-12-30", "to_date": "9999-12-31"},
    ],
)
def test_analytics_reject_invalid_ranges(client, clock, params):
    headers = login(client)
    for path in ("summary", "intensity"):
        assert (
            client.get(
                f"/api/v1/analytics/{path}", headers=headers, params=params
            ).status_code
            == 422
        )


def test_reversed_filters_rejected(client):
    headers = login(client)
    params = {"from_date": "2026-10-11", "to_date": "2026-10-10"}
    for path in (
        "/api/v1/diary",
        "/api/v1/attacks",
        "/api/v1/analytics/export?format=csv",
    ):
        assert client.get(path, headers=headers, params=params).status_code == 422


def test_accounts_cannot_read_or_modify_each_others_data(client, clock):
    alice = login(client, "alice@example.com")
    bob = login(client, "bob@example.com")
    record = attack(client, alice, medications=["A"], relief_factors=["Отдых"])
    client.put(
        "/api/v1/diary/2026-10-10", headers=alice, json={"headache_present": True}
    )
    path = f"/api/v1/attacks/{record['id']}"
    assert client.get(path, headers=bob).status_code == 404
    assert client.put(path, headers=bob, json={"intensity": 1}).status_code == 404
    assert client.delete(path, headers=bob).status_code == 404
    assert client.get("/api/v1/diary/2026-10-10", headers=bob).status_code == 404
    assert client.get("/api/v1/attacks", headers=bob).json() == []
    assert (
        client.get("/api/v1/analytics/summary", headers=bob).json()["total_attacks"]
        == 0
    )
    chart = client.get("/api/v1/analytics/intensity", headers=bob).json()
    assert all(
        p["total_attacks"] == 0 and not p["diary_recorded"] for p in chart["points"]
    )
    assert (
        len(
            client.get(
                "/api/v1/analytics/export?format=csv", headers=bob
            ).text.splitlines()
        )
        == 1
    )
    client.put(
        "/api/v1/diary/2026-10-10", headers=bob, json={"headache_present": False}
    )
    assert (
        client.get("/api/v1/diary/2026-10-10", headers=alice).json()["headache_present"]
        is True
    )
    for path in (
        "/api/v1/analytics/summary",
        "/api/v1/analytics/intensity",
        "/api/v1/diary",
    ):
        assert client.get(path).status_code == 401


def test_dst_day_and_leap_day(client, clock):
    headers = login(client)
    # March 29 in Berlin is 23 hours long in 2026.
    attack(client, headers, "2026-03-28T22:59:59Z", 10)
    attack(client, headers, "2026-03-28T23:00:00Z", 3)
    attack(client, headers, "2026-03-29T21:59:59Z", 7)
    attack(client, headers, "2026-03-29T22:00:00Z", 10)
    params = {
        "from_date": "2026-03-29",
        "to_date": "2026-03-29",
        "time_zone": "Europe/Berlin",
    }
    point = client.get(
        "/api/v1/analytics/intensity", headers=headers, params=params
    ).json()["points"][0]
    assert point["total_attacks"] == 2
    assert point["avg_intensity"] == 5
    params = {"from_date": "2024-02-28", "to_date": "2024-03-01"}
    points = client.get(
        "/api/v1/analytics/intensity", headers=headers, params=params
    ).json()["points"]
    assert [p["date"] for p in points] == ["2024-02-28", "2024-02-29", "2024-03-01"]


def test_future_end_not_counted_and_long_completed_attack_uses_full_duration(
    client, clock
):
    headers = login(client)
    finished = attack(client, headers, "2026-10-09T23:30:00Z", 3)
    assert (
        client.put(
            f"/api/v1/attacks/{finished['id']}",
            headers=headers,
            json={"end_time": "2026-10-10T01:30:00Z"},
        ).status_code
        == 200
    )
    future_end = attack(client, headers, "2026-10-10T11:00:00Z", 7)
    client.put(
        f"/api/v1/attacks/{future_end['id']}",
        headers=headers,
        json={"end_time": "2026-10-12T01:30:00Z"},
    )
    params = {"from_date": "2026-10-09", "to_date": "2026-10-09"}
    summary = client.get(
        "/api/v1/analytics/summary", headers=headers, params=params
    ).json()
    assert summary["avg_duration_minutes"] == 120
    summary = client.get("/api/v1/analytics/summary", headers=headers).json()
    assert summary["completed_attacks"] == 1
    assert summary["avg_duration_minutes"] == 120
