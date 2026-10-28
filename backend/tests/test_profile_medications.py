
def account(client, email="profile@example.com"):
    assert client.post("/api/v1/auth/register", json={"email": email, "password": "old-password123", "name": "Profile"}).status_code == 201
    tokens = client.post("/api/v1/auth/login", json={"email": email, "password": "old-password123"}).json()
    return {"Authorization": "Bearer " + tokens["access_token"]}, tokens


def test_password_change_checks_old_password_and_revokes_old_sessions(client):
    headers, old = account(client)
    path = "/api/v1/auth/password"
    bad = client.put(path, headers=headers, json={"current_password": "wrong", "new_password": "new-password123"})
    assert bad.status_code == 400
    assert client.get("/api/v1/user/profile", headers=headers).status_code == 200
    response = client.put(path, headers=headers, json={"current_password": "old-password123", "new_password": "new-password123"})
    assert response.status_code == 200
    fresh = response.json()
    assert client.get("/api/v1/user/profile", headers={"Authorization": "Bearer " + fresh["access_token"]}).status_code == 200
    assert client.get("/api/v1/user/profile", headers=headers).status_code == 401
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": old["refresh_token"]}).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "profile@example.com", "password": "old-password123"}).status_code == 401
    assert client.post("/api/v1/auth/login", json={"email": "profile@example.com", "password": "new-password123"}).status_code == 200


def test_password_validation_and_authentication(client):
    headers, _ = account(client)
    assert client.put("/api/v1/auth/password", json={"current_password": "old-password123", "new_password": "new-password123"}).status_code == 401
    for password in ["short", "old-password123", "x" * 129]:
        assert client.put("/api/v1/auth/password", headers=headers, json={"current_password": "old-password123", "new_password": password}).status_code == 422


def test_profile_name_trims_and_rejects_blank(client):
    headers, _ = account(client)
    for name in ["", "   ", "x" * 121]:
        assert client.put("/api/v1/user/profile", headers=headers, json={"name": name}).status_code == 422
    response = client.put("/api/v1/user/profile", headers=headers, json={"name": "  Новое имя  "})
    assert response.status_code == 200
    assert response.json()["name"] == "Новое имя"


def test_medication_catalog_and_custom_names_are_private_and_deduplicated(client):
    alice, _ = account(client, "alice-profile@example.com")
    bob, _ = account(client, "bob-profile@example.com")
    path = "/api/v1/medications"
    for name in ["", "   ", "x" * 121]:
        assert client.post(path, headers=alice, json={"name": name}).status_code == 422
    custom = client.post(path, headers=alice, json={"name": "  Мой препарат  "})
    assert custom.status_code == 201
    assert custom.json()["name"] == "Мой препарат"
    repeat = client.post(path, headers=alice, json={"name": "мой ПРЕПАРАТ"})
    assert repeat.status_code == 201
    assert repeat.json()["id"] == custom.json()["id"]
    assert len(client.get(path, headers=alice).json()) == 1
    assert client.get(path + "/catalog", headers=alice, params={"query": "мой"}).json() == ["Мой препарат"]
    assert client.get(path + "/catalog", headers=bob, params={"query": "мой"}).json() == []
    assert "Ибупрофен" in client.get(path + "/catalog", headers=bob, params={"query": "ИБУ"}).json()
    assert client.get(path + "/catalog").status_code == 401
