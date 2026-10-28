import struct
import zlib

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32
JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 32


def tiny_png() -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))

    raw = zlib.compress(b"\x00\xff\x00\x00")
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0)) + chunk(b"IDAT", raw) + chunk(b"IEND", b"")


def account(client, email):
    assert client.post("/api/v1/auth/register", json={"email": email, "password": "password123", "name": "Avatar"}).status_code == 201
    tokens = client.post("/api/v1/auth/login", json={"email": email, "password": "password123"}).json()
    return {"Authorization": "Bearer " + tokens["access_token"]}


def upload(client, headers, data, content_type="image/png", name="avatar.png"):
    return client.put("/api/v1/user/avatar", headers=headers, files={"file": (name, data, content_type)})


def test_avatar_upload_read_replace_and_delete(client):
    headers = account(client, "avatar@example.com")
    profile = client.get("/api/v1/user/profile", headers=headers).json()
    assert profile["avatar_updated_at"] is None
    assert client.get("/api/v1/user/avatar", headers=headers).status_code == 404

    png = tiny_png()
    uploaded = upload(client, headers, png)
    assert uploaded.status_code == 200
    assert uploaded.json()["avatar_updated_at"] is not None

    fetched = client.get("/api/v1/user/avatar", headers=headers)
    assert fetched.status_code == 200
    assert fetched.headers["content-type"] == "image/png"
    assert fetched.content == png

    # Тип определяется по содержимому, а не по заявленному Content-Type.
    replaced = upload(client, headers, JPEG, content_type="image/png", name="photo.png")
    assert replaced.status_code == 200
    assert client.get("/api/v1/user/avatar", headers=headers).headers["content-type"] == "image/jpeg"

    assert client.delete("/api/v1/user/avatar", headers=headers).status_code == 204
    assert client.get("/api/v1/user/avatar", headers=headers).status_code == 404
    assert client.get("/api/v1/user/profile", headers=headers).json()["avatar_updated_at"] is None
    assert client.delete("/api/v1/user/avatar", headers=headers).status_code == 204


def test_avatar_rejects_non_images_and_large_files(client):
    headers = account(client, "reject@example.com")
    assert upload(client, headers, b"<svg></svg>", content_type="image/svg+xml", name="x.svg").status_code == 422
    assert upload(client, headers, b"not an image", content_type="image/jpeg", name="x.jpg").status_code == 422
    big = PNG + b"\x00" * (2 * 1024 * 1024)
    assert upload(client, headers, big).status_code == 413
    assert client.get("/api/v1/user/avatar", headers=headers).status_code == 404


def test_avatar_is_private_to_its_owner(client):
    owner = account(client, "owner@example.com")
    other = account(client, "other@example.com")
    assert upload(client, owner, tiny_png()).status_code == 200
    assert client.get("/api/v1/user/avatar", headers=other).status_code == 404
    assert client.get("/api/v1/user/avatar").status_code == 401
    assert client.put("/api/v1/user/avatar", files={"file": ("a.png", tiny_png(), "image/png")}).status_code == 401


def test_profile_personal_fields_can_be_set_and_cleared(client):
    headers = account(client, "personal@example.com")
    saved = client.put("/api/v1/user/profile", headers=headers, json={"birth_date": "1999-05-04", "gender": "female", "time_zone": "Asia/Tomsk"})
    assert saved.status_code == 200
    assert (saved.json()["birth_date"], saved.json()["gender"], saved.json()["time_zone"]) == ("1999-05-04", "female", "Asia/Tomsk")
    cleared = client.put("/api/v1/user/profile", headers=headers, json={"birth_date": None, "gender": None})
    assert cleared.status_code == 200
    assert (cleared.json()["birth_date"], cleared.json()["gender"], cleared.json()["time_zone"]) == (None, None, "Asia/Tomsk")
