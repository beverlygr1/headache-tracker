import os
import subprocess
import sys
from pathlib import Path

import sqlalchemy as sa


def test_migration_keeps_history_and_only_skips_existing_diary_users(tmp_path):
    backend = Path(__file__).resolve().parents[1]
    database_url = f"sqlite:///{(tmp_path / 'migration.db').as_posix()}"
    env = {**os.environ, "DATABASE_URL": database_url}

    def migrate(*args):
        subprocess.run(
            [sys.executable, "-m", "alembic", *args],
            cwd=backend,
            env=env,
            capture_output=True,
            text=True,
            check=True,
        )

    migrate("upgrade", "0001_initial")
    engine = sa.create_engine(database_url)
    with engine.begin() as connection:
        for user_id in (1, 2, 3):
            connection.execute(
                sa.text(
                    "INSERT INTO users (id, email, password_hash, name) VALUES (:id, :email, 'test', 'User')"
                ),
                {"id": user_id, "email": f"user{user_id}@example.com"},
            )
        connection.execute(
            sa.text(
                "INSERT INTO attacks (user_id, start_time, intensity) VALUES (1, '2026-10-07 10:00:00', 4)"
            )
        )
        connection.execute(
            sa.text(
                "INSERT INTO diary_entries (user_id, date, sleep_hours) VALUES (2, '2026-10-07', 8)"
            )
        )
    engine.dispose()
    migrate("upgrade", "head")
    engine = sa.create_engine(database_url)
    with engine.begin() as connection:
        rows = connection.execute(
            sa.text(
                "SELECT id, onboarding_step, onboarding_completed FROM users ORDER BY id"
            )
        ).all()
        assert rows == [(1, 1, 1), (2, 1, 1), (3, 0, 0)]
        connection.execute(
            sa.text(
                "INSERT INTO users (email, password_hash, name) VALUES ('new@example.com', 'test', 'New')"
            )
        )
        assert (
            connection.execute(
                sa.text(
                    "SELECT onboarding_completed FROM users WHERE email = 'new@example.com'"
                )
            ).scalar_one()
            == 0
        )
    engine.dispose()
    migrate("downgrade", "0001_initial")
    engine = sa.create_engine(database_url)
    with engine.connect() as connection:
        assert (
            connection.execute(sa.text("SELECT count(*) FROM users")).scalar_one() == 4
        )
        assert (
            connection.execute(sa.text("SELECT count(*) FROM attacks")).scalar_one()
            == 1
        )
        assert (
            connection.execute(
                sa.text("SELECT count(*) FROM diary_entries")
            ).scalar_one()
            == 1
        )
        assert "onboarding_completed" not in {
            col["name"] for col in sa.inspect(connection).get_columns("users")
        }
    engine.dispose()
