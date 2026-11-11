"""diary physical fatigue

Revision ID: 0006_diary_physical_fatigue
Revises: 0005_predictions
Create Date: 2026-11-10
"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006_diary_physical_fatigue"
down_revision: str | None = "0005_predictions"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "diary_entries", sa.Column("physical_fatigue", sa.Boolean(), nullable=True)
    )


def downgrade() -> None:
    with op.batch_alter_table("diary_entries") as batch:
        batch.drop_column("physical_fatigue")
