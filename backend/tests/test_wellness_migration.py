import os
import subprocess
import sys
from pathlib import Path

import sqlalchemy as sa
from fastapi.testclient import TestClient
from sqlalchemy.orm import sessionmaker

from app.db.session import get_db
from app.main import app

WELLNESS_TABLES = {"user_medications", "user_settings", "user_supplements"}


def _migrate(backend: Path, url: str, *args: str) -> None:
    subprocess.run(
        [sys.executable, "-m", "alembic", *args],
        cwd=backend,
        env={**os.environ, "DATABASE_URL": url},
        capture_output=True,
        text=True,
        check=True,
    )


def test_migrations_create_wellness_tables_used_by_endpoints(tmp_path):
    backend = Path(__file__).resolve().parents[1]
    url = f"sqlite:///{(tmp_path / 'wellness.db').as_posix()}"

    _migrate(backend, url, "upgrade", "0004_merge_diary_backend")
    engine = sa.create_engine(url, connect_args={"check_same_thread": False})
    try:
        assert not WELLNESS_TABLES & set(sa.inspect(engine).get_table_names())

        _migrate(backend, url, "upgrade", "head")
        assert WELLNESS_TABLES <= set(sa.inspect(engine).get_table_names())

        # Ручки работают на схеме из миграций, а не из create_all.
        session = sessionmaker(bind=engine, expire_on_commit=False)

        def override_get_db():
            db = session()
            try:
                yield db
            finally:
                db.close()

        app.dependency_overrides[get_db] = override_get_db
        try:
            with TestClient(app) as client:
                client.post("/api/v1/auth/register", json={"email": "kit@example.com", "password": "password123", "name": "Kit"})
                tokens = client.post("/api/v1/auth/login", json={"email": "kit@example.com", "password": "password123"}).json()
                headers = {"Authorization": f"Bearer {tokens['access_token']}"}

                created = client.post("/api/v1/medications", headers=headers, json={"name": "Ибупрофен", "dosage": "200 мг"})
                assert created.status_code == 201
                assert client.get("/api/v1/medications", headers=headers).json()[0]["name"] == "Ибупрофен"

                assert client.get("/api/v1/prevention/settings", headers=headers).status_code == 200

                supplement = client.post("/api/v1/prevention/supplements", headers=headers, json={"name": "Магний", "intake_time": "09:00"})
                assert supplement.status_code == 201
                assert len(client.get("/api/v1/prevention/supplements", headers=headers).json()) == 1
        finally:
            app.dependency_overrides.clear()

        _migrate(backend, url, "downgrade", "0004_merge_diary_backend")
        assert not WELLNESS_TABLES & set(sa.inspect(engine).get_table_names())
        assert sa.inspect(engine).has_table("attacks")
    finally:
        engine.dispose()
