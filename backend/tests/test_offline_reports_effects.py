import io
from datetime import UTC, datetime
from uuid import uuid4

from app.services import analytics
from pypdf import PdfReader


def account(client, email="new-flows@example.com", name="Пациент"):
    assert client.post("/api/v1/auth/register", json={"email": email, "password": "password123", "name": name}).status_code == 201
    result = client.post("/api/v1/auth/login", json={"email": email, "password": "password123"})
    return {"Authorization": "Bearer " + result.json()["access_token"]}


def payload(**values):
    return {"start_time": "2026-11-05T03:00:00Z", "intensity": 5, "medications": ["Препарат A", "Препарат B"], **values}


def test_medication_results_roundtrip_and_removal(client):
    headers = account(client)
    created = client.post("/api/v1/attacks", headers=headers, json=payload(medication_effects={"Препарат A": "helped", "Препарат B": "partly"}))
    assert created.status_code == 201
    path = f"/api/v1/attacks/{created.json()['id']}"
    assert client.get(path, headers=headers).json()["medication_effects"] == {"Препарат A": "helped", "Препарат B": "partly"}
    updated = client.put(path, headers=headers, json={"medication_effects": {"Препарат A": "not_helped"}})
    assert updated.json()["medication_effects"] == {"Препарат A": "not_helped"}
    assert client.put(path, headers=headers, json={"intensity": 7}).json()["medication_effects"] == {"Препарат A": "not_helped"}
    assert client.put(path, headers=headers, json={"medications": ["Препарат B"]}).json()["medication_effects"] == {}
    assert client.put(path, headers=headers, json={"medication_effects": {}}).status_code == 200


def test_invalid_medication_results_do_not_mutate_record(client):
    headers = account(client)
    assert client.post("/api/v1/attacks", headers=headers, json=payload(medication_effects={"Чужое название": "helped"})).status_code == 422
    record = client.post("/api/v1/attacks", headers=headers, json=payload()).json()
    path = f"/api/v1/attacks/{record['id']}"
    for invalid in ({"Чужое название": "helped"}, {"Препарат A": "unknown"}, None):
        assert client.put(path, headers=headers, json={"intensity": 9, "medication_effects": invalid}).status_code == 422
        assert client.get(path, headers=headers).json()["intensity"] == 5


def test_offline_create_can_be_replayed_after_lost_response_and_edit(client):
    headers = account(client)
    data = payload(client_request_id=str(uuid4()))
    first = client.post("/api/v1/attacks", headers=headers, json=data)
    second = client.post("/api/v1/attacks", headers=headers, json=data)
    assert first.status_code == second.status_code == 201
    assert first.json()["id"] == second.json()["id"]
    client.put(f"/api/v1/attacks/{first.json()['id']}", headers=headers, json={"intensity": 6})
    replay = client.post("/api/v1/attacks", headers=headers, json=data)
    assert replay.json()["id"] == first.json()["id"]
    assert replay.json()["intensity"] == 6
    assert len(client.get("/api/v1/attacks", headers=headers).json()) == 1
    conflict = client.post("/api/v1/attacks", headers=headers, json={**data, "intensity": 8})
    assert conflict.status_code == 409


def test_offline_identifiers_and_results_are_scoped_to_account(client):
    alice = account(client, "alice-results@example.com")
    bob = account(client, "bob-results@example.com")
    data = payload(client_request_id=str(uuid4()), medication_effects={"Препарат A": "helped"})
    a = client.post("/api/v1/attacks", headers=alice, json=data).json()
    b = client.post("/api/v1/attacks", headers=bob, json=data).json()
    assert a["id"] != b["id"]
    assert client.get(f"/api/v1/attacks/{a['id']}", headers=bob).status_code == 404
    assert client.put(f"/api/v1/attacks/{a['id']}", headers=bob, json={"medication_effects": {}}).status_code == 404


def fixed_now(monkeypatch):
    monkeypatch.setattr(analytics, "_now", lambda: datetime(2026, 11, 10, 12, tzinfo=UTC))


def pdf(client, headers, **params):
    return client.get("/api/v1/analytics/export", headers=headers, params={"format": "pdf", "from_date": "2026-11-05", "to_date": "2026-11-05", "time_zone": "Asia/Tomsk", **params})


def test_pdf_is_private_handles_cyrillic_zeroes_and_account_time_zone(client, monkeypatch):
    fixed_now(monkeypatch)
    alice = account(client, "alice-report@example.com", "Анна <&>")
    bob = account(client, "bob-report@example.com", "OTHER_SECRET_NAME")
    client.post("/api/v1/attacks", headers=alice, json=payload(start_time="2026-11-04T19:00:00Z", medications=["Название <&>"], medication_effects={"Название <&>": "partly"}))
    client.post("/api/v1/attacks", headers=alice, json=payload(start_time="2026-11-05T18:00:00Z", medications=["NEXT_DAY_SECRET"]))
    client.post("/api/v1/attacks", headers=bob, json=payload(medications=["OTHER_SECRET_MEDICATION"]))
    client.put("/api/v1/diary/2026-11-05", headers=alice, json={"sleep_hours": 0, "caffeine_intake": 0, "headache_present": False})
    response = pdf(client, alice)
    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["cache-control"] == "no-store"
    assert response.content.startswith(b"%PDF")
    reader = PdfReader(io.BytesIO(response.content))
    text = "\n".join(page.extract_text() for page in reader.pages)
    for expected in ("Дневник головной боли", "Анна <&>", "Название <&>", "Частично помог", "05.11.2026 02:00", "Самочувствие по дням", "Нет"):
        assert expected in text
    for unexpected in ("OTHER_SECRET", "NEXT_DAY_SECRET"):
        assert unexpected not in text
    fonts = reader.pages[0]["/Resources"]["/Font"]
    assert any(font.get_object().get("/FontDescriptor", {}).get("/FontFile2") for font in fonts.values())


def test_pdf_empty_range_and_invalid_ranges(client, monkeypatch):
    fixed_now(monkeypatch)
    headers = account(client)
    response = pdf(client, headers)
    assert response.status_code == 200
    text = "\n".join(page.extract_text() for page in PdfReader(io.BytesIO(response.content)).pages)
    assert "За выбранный период записей о приступах нет." in text
    assert "Средняя интенсивность: —" in text
    assert pdf(client, headers, time_zone="Invalid/Timezone").status_code == 422
    assert pdf(client, headers, from_date="2024-01-01").status_code == 422
    assert pdf(client, headers, from_date="2026-11-06").status_code == 422
    assert pdf(client, {}).status_code == 401


def test_pdf_long_medication_list_can_span_pages(client, monkeypatch):
    fixed_now(monkeypatch)
    headers = account(client)
    names = [f"Препарат {i}: " + "Длинное название " * 6 for i in range(40)]
    assert client.post("/api/v1/attacks", headers=headers, json=payload(medications=names)).status_code == 201
    response = pdf(client, headers)
    assert response.status_code == 200
    reader = PdfReader(io.BytesIO(response.content))
    assert len(reader.pages) >= 2
    text = "\n".join(page.extract_text() for page in reader.pages)
    assert "Препарат 39:" in text
