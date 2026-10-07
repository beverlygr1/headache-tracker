import pytest


def login(client, email):
    response = client.post(
        "/api/v1/auth/login", json={"email": email, "password": "password123"}
    )
    assert response.status_code == 200
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def register(client, email):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": "password123",
            "name": "New user",
        },
    )
    assert response.status_code == 201
    return login(client, email)


def test_progress_survives_login_and_completion_is_monotonic(client):
    headers = register(client, "first@example.com")
    profile = client.get("/api/v1/user/profile", headers=headers).json()
    assert profile["onboarding_step"] == 0
    assert profile["onboarding_completed"] is False

    response = client.put("/api/v1/user/onboarding", headers=headers, json={"step": 1})
    assert response.status_code == 200
    headers = login(client, "first@example.com")
    assert (
        client.get("/api/v1/user/profile", headers=headers).json()["onboarding_step"]
        == 1
    )

    back = client.put("/api/v1/user/onboarding", headers=headers, json={"step": 0})
    assert back.json()["onboarding_step"] == 0
    skipped = client.put(
        "/api/v1/user/onboarding", headers=headers, json={"step": 0, "completed": True}
    )
    assert skipped.status_code == 200
    assert skipped.json()["onboarding_completed"] is True
    assert skipped.json()["onboarding_step"] == 1

    stale = client.put(
        "/api/v1/user/onboarding", headers=headers, json={"step": 0, "completed": False}
    )
    assert stale.json()["onboarding_completed"] is True
    assert stale.json()["onboarding_step"] == 1
    headers = login(client, "first@example.com")
    assert (
        client.get("/api/v1/user/profile", headers=headers).json()[
            "onboarding_completed"
        ]
        is True
    )
    renamed = client.put(
        "/api/v1/user/profile", headers=headers, json={"name": "Renamed"}
    )
    assert renamed.json()["onboarding_completed"] is True
    assert client.get("/api/v1/attacks", headers=headers).json() == []
    assert client.get("/api/v1/diary", headers=headers).json() == []


def test_onboarding_is_scoped_to_authenticated_user(client):
    first = register(client, "one@example.com")
    second = register(client, "two@example.com")
    assert client.put("/api/v1/user/onboarding", json={"step": 1}).status_code == 401
    client.put(
        "/api/v1/user/onboarding", headers=first, json={"step": 1, "completed": True}
    )
    assert (
        client.get("/api/v1/user/profile", headers=second).json()[
            "onboarding_completed"
        ]
        is False
    )
    assert (
        client.put(
            "/api/v1/user/onboarding", headers=second, json={"step": 1, "user_id": 1}
        ).status_code
        == 422
    )
    assert (
        client.get("/api/v1/user/profile", headers=first).json()["onboarding_completed"]
        is True
    )


@pytest.mark.parametrize(
    "payload",
    [
        {},
        {"step": -1},
        {"step": 2},
        {"step": None},
        {"step": True},
        {"step": "1"},
        {"step": 0.5},
        {"step": 1, "completed": None},
        {"step": 1, "completed": "true"},
    ],
)
def test_invalid_progress_does_not_change_account(client, payload):
    headers = register(client, "invalid@example.com")
    assert (
        client.put("/api/v1/user/onboarding", headers=headers, json=payload).status_code
        == 422
    )
    profile = client.get("/api/v1/user/profile", headers=headers).json()
    assert profile["onboarding_step"] == 0
    assert profile["onboarding_completed"] is False


def test_daily_record_can_clear_fields_without_losing_other_factors(client):
    headers = register(client, "diary@example.com")
    path = "/api/v1/diary/2026-10-07"
    initial = client.put(
        path,
        headers=headers,
        json={
            "sleep_hours": 7.5,
            "sleep_quality": 8,
            "water_ml": 1500,
            "stress_level": 4,
            "caffeine_intake": 2,
        },
    )
    assert initial.status_code == 200
    updated = client.put(
        path,
        headers=headers,
        json={
            "sleep_hours": 8,
            "water_ml": None,
            "stress_level": None,
        },
    )
    assert updated.status_code == 200
    assert updated.json()["water_ml"] is None
    assert updated.json()["stress_level"] is None
    assert updated.json()["sleep_quality"] == 8
    assert updated.json()["caffeine_intake"] == 2
    assert len(client.get("/api/v1/diary", headers=headers).json()) == 1
    assert client.get("/api/v1/attacks", headers=headers).json() == []
