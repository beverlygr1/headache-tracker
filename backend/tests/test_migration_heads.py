from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory


def test_backend_has_one_migration_head():
    backend = Path(__file__).resolve().parents[1]
    migrations = ScriptDirectory.from_config(Config(str(backend / "alembic.ini")))
    assert len(migrations.get_heads()) == 1
