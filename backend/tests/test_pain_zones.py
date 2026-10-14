import pytest


def _headers(client, email):
    registered = client.post(
        "/api/v1/auth/register",
        json={"email": email, "password": "password123", "name": "Zone tester"},
    )
    assert registered.status_code == 201
    login = client.post(
        "/api/v1/auth/login",
        json={"email": email, "password": "password123"},
    )
    assert login.status_code == 200
    return {"Authorization": f"Bearer {login.json()['access_token']}"}


def test_review_payload_saves_and_restores_multiple_zones(client):
    headers = _headers(client, "zones@example.com")
    payload = {
        "start_time": "2026-10-08T09:30:00+07:00",
        "intensity": 6,
        "localization": "Лоб, Темя, Затылок",
        "symptoms": ["Тошнота", "Свет мешает"],
    }
    created = client.post("/api/v1/attacks", headers=headers, json=payload)
    assert created.status_code == 201
    attack_id = created.json()["id"]
    # A new request reads the committed record, rather than the create response.
    loaded = client.get(f"/api/v1/attacks/{attack_id}", headers=headers)
    assert loaded.status_code == 200
    assert loaded.json()["localization"] == payload["localization"]
    assert loaded.json()["symptoms"] == payload["symptoms"]
    assert loaded.json()["intensity"] == 6
    assert loaded.json()["start_time"].startswith("2026-10-08T02:30:00")
    assert loaded.json()["end_time"] is None
    listed = client.get("/api/v1/attacks", headers=headers)
    assert listed.json()[0]["localization"].split(", ") == ["Лоб", "Темя", "Затылок"]


def test_zone_changes_preserve_completed_attack_and_other_fields(client):
    headers = _headers(client, "edit-zones@example.com")
    created = client.post(
        "/api/v1/attacks",
        headers=headers,
        json={
            "start_time": "2026-10-08T09:30:00+07:00",
            "intensity": 4,
            "localization": "Виски",
            "symptoms": ["Тошнота"],
            "medications": ["Записанное лекарство"],
        },
    )
    attack_id = created.json()["id"]
    finished = client.put(
        f"/api/v1/attacks/{attack_id}",
        headers=headers,
        json={"end_time": "2026-10-08T10:15:00+07:00"},
    )
    assert finished.status_code == 200
    edited = client.put(
        f"/api/v1/attacks/{attack_id}",
        headers=headers,
        json={"localization": "Лоб, Затылок", "intensity": 7, "symptoms": []},
    )
    assert edited.status_code == 200
    loaded = client.get(f"/api/v1/attacks/{attack_id}", headers=headers).json()
    assert loaded["localization"] == "Лоб, Затылок"
    assert loaded["symptoms"] == []
    assert loaded["medications"] == ["Записанное лекарство"]
    assert loaded["end_time"] == finished.json()["end_time"]
    assert len(client.get("/api/v1/attacks", headers=headers).json()) == 1


def test_selected_zones_remain_private_to_the_record_owner(client):
    owner = _headers(client, "zone-owner@example.com")
    other = _headers(client, "zone-other@example.com")
    attack_id = client.post(
        "/api/v1/attacks",
        headers=owner,
        json={
            "start_time": "2026-10-08T09:30:00Z",
            "intensity": 6,
            "localization": "Лоб, Затылок",
        },
    ).json()["id"]
    assert client.get(f"/api/v1/attacks/{attack_id}").status_code == 401
    assert client.get(f"/api/v1/attacks/{attack_id}", headers=other).status_code == 404
    assert client.put(
        f"/api/v1/attacks/{attack_id}", headers=other, json={"localization": "Темя"}
    ).status_code == 404
    assert client.get("/api/v1/attacks", headers=other).json() == []


@pytest.mark.parametrize("intensity", [0, 11])
def test_invalid_review_payload_is_rejected_without_saving(client, intensity):
    headers = _headers(client, "zone-validation@example.com")
    response = client.post(
        "/api/v1/attacks",
        headers=headers,
        json={
            "start_time": "2026-10-08T09:30:00Z",
            "intensity": intensity,
            "localization": "Лоб, Затылок",
        },
    )
    assert response.status_code == 422
    response = client.post(
        "/api/v1/attacks",
        headers=headers,
        json={
            "start_time": "2026-10-08T09:30:00Z",
            "intensity": 6,
            "localization": "Я" * 121,
        },
    )
    assert response.status_code == 422
    assert client.get("/api/v1/attacks", headers=headers).json() == []
