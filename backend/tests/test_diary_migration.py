import os
import subprocess
import sys
from pathlib import Path

import pytest
import sqlalchemy as sa


@pytest.mark.parametrize(
    "dialect",
    ["sqlite"] + (["postgresql"] if os.environ.get("TEST_DATABASE_URL") else []),
)
def test_headache_migration_preserves_history_and_unknown_labels(tmp_path, dialect):
    backend = Path(__file__).resolve().parents[1]
    url = (
        os.environ["TEST_DATABASE_URL"]
        if dialect == "postgresql"
        else f"sqlite:///{(tmp_path / 'diary-migration.db').as_posix()}"
    )
    if dialect == "postgresql":
        assert sa.engine.make_url(url).database.endswith("_test")
    env = {**os.environ, "DATABASE_URL": url}

    def migrate(*args):
        return subprocess.run(
            [sys.executable, "-m", "alembic", *args],
            cwd=backend,
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )

    migrate("upgrade", "0002_onboarding")
    engine = sa.create_engine(url)
    try:
        with engine.begin() as db:
            db.execute(
                sa.text(
                    "INSERT INTO users (id, email, password_hash, name) VALUES (1, 'migration@example.com', 'test', 'User')"
                )
            )
            db.execute(
                sa.text(
                    "INSERT INTO diary_entries (user_id, date, sleep_hours, water_ml) VALUES (1, '2026-10-10', 7.5, 1500)"
                )
            )
            db.execute(
                sa.text(
                    "INSERT INTO attacks (user_id, start_time, intensity) VALUES (1, '2026-10-10 10:00:00', 6)"
                )
            )
        migrate("upgrade", "head")
        with engine.begin() as db:
            row = db.execute(
                sa.text(
                    "SELECT headache_present, sleep_hours, water_ml FROM diary_entries"
                )
            ).one()
            assert row == (None, 7.5, 1500)
            assert (
                db.execute(
                    sa.text("SELECT version_num FROM alembic_version")
                ).scalar_one()
                == "0003_diary_headache"
            )
            db.execute(
                sa.text("UPDATE diary_entries SET headache_present = :value"),
                {"value": False},
            )
        migrate("downgrade", "0002_onboarding")
        with engine.connect() as db:
            assert "headache_present" not in {
                column["name"] for column in sa.inspect(db).get_columns("diary_entries")
            }
            assert db.execute(
                sa.text("SELECT sleep_hours, water_ml FROM diary_entries")
            ).one() == (7.5, 1500)
            assert db.execute(sa.text("SELECT count(*) FROM attacks")).scalar_one() == 1
            assert (
                db.execute(sa.text("SELECT onboarding_step FROM users")).scalar_one()
                == 0
            )
        migrate("upgrade", "head")
        with engine.connect() as db:
            assert (
                db.execute(
                    sa.text("SELECT headache_present FROM diary_entries")
                ).scalar_one()
                is None
            )
        if dialect == "postgresql":
            migrate("check")
    finally:
        engine.dispose()
        if dialect == "postgresql":
            migrate("downgrade", "base")


def test_postgresql_migration_sql_has_nullable_boolean():
    backend = Path(__file__).resolve().parents[1]
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "alembic",
            "upgrade",
            "0002_onboarding:0003_diary_headache",
            "--sql",
        ],
        cwd=backend,
        env={
            **os.environ,
            "DATABASE_URL": "postgresql+psycopg://test:test@localhost/headache_tracker_test",
        },
        capture_output=True,
        text=True,
        check=True,
    )
    assert "ADD COLUMN headache_present BOOLEAN" in result.stdout
    assert "headache_present BOOLEAN NOT NULL" not in result.stdout
