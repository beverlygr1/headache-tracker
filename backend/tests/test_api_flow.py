def test_auth_attack_diary_flow(client):
    register = client.post("/api/v1/auth/register", json={"email": "tester@example.com", "password": "password123", "name": "Tester"})
    assert register.status_code == 201
    duplicate = client.post("/api/v1/auth/register", json={"email": "tester@example.com", "password": "password123", "name": "Tester"})
    assert duplicate.status_code == 409

    login = client.post("/api/v1/auth/login", json={"email": "tester@example.com", "password": "password123"})
    assert login.status_code == 200
    tokens = login.json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    profile = client.get("/api/v1/user/profile", headers=headers)
    assert profile.status_code == 200
    assert profile.json()["email"] == "tester@example.com"

    created = client.post("/api/v1/attacks", headers=headers, json={"start_time": "2026-09-23T12:00:00Z", "intensity": 7, "pain_type": "pulsating", "localization": "left"})
    assert created.status_code == 201
    attack_id = created.json()["id"]

    attacks = client.get("/api/v1/attacks", headers=headers)
    assert attacks.status_code == 200
    assert len(attacks.json()) == 1
    assert attacks.json()[0]["id"] == attack_id

    diary = client.put("/api/v1/diary/2026-09-23", headers=headers, json={"sleep_hours": 7.5, "stress_level": 4, "water_ml": 1500})
    assert diary.status_code == 200
    assert diary.json()["sleep_hours"] == 7.5

    summary = client.get("/api/v1/analytics/summary?period=year", headers=headers)
    assert summary.status_code == 200
    assert summary.json()["total_attacks"] == 1

    csv_export = client.get("/api/v1/analytics/export?format=csv", headers=headers)
    assert csv_export.status_code == 200
    assert "start_time" in csv_export.text

    forecast = client.get("/api/v1/forecast/risk", headers=headers)
    assert forecast.status_code == 501

    deleted = client.delete(f"/api/v1/attacks/{attack_id}", headers=headers)
    assert deleted.status_code == 204


def test_attack_end_time_timezones(client):
    client.post("/api/v1/auth/register", json={"email": "tz@example.com", "password": "password123", "name": "Tz"})
    tokens = client.post("/api/v1/auth/login", json={"email": "tz@example.com", "password": "password123"}).json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    attack_id = client.post("/api/v1/attacks", headers=headers, json={"start_time": "2026-09-23T12:00:00+07:00", "intensity": 5}).json()["id"]

    aware = client.put(f"/api/v1/attacks/{attack_id}", headers=headers, json={"end_time": "2026-09-23T13:30:00+07:00"})
    assert aware.status_code == 200
    assert aware.json()["end_time"].startswith("2026-09-23T06:30:00")

    naive = client.put(f"/api/v1/attacks/{attack_id}", headers=headers, json={"end_time": "2026-09-23T06:00:00"})
    assert naive.status_code == 200

    before_start = client.put(f"/api/v1/attacks/{attack_id}", headers=headers, json={"end_time": "2026-09-23T04:00:00Z"})
    assert before_start.status_code == 422

    summary = client.get("/api/v1/analytics/summary?period=year", headers=headers)
    assert summary.json()["avg_duration_minutes"] == 60.0
