"""Create medication, settings and supplement tables.

Revision 0e572476098e declared these models but its upgrade() was empty,
so databases migrated with Alembic never got the tables and
/medications and /prevention answered 500.

Revision ID: 0005_wellness_tables
Revises: 0004_merge_diary_backend
"""

import sqlalchemy as sa
from alembic import op

revision = "0005_wellness_tables"
down_revision = "0004_merge_diary_backend"
branch_labels = None
depends_on = None


def upgrade() -> None:
    existing = set(sa.inspect(op.get_bind()).get_table_names())

    if "user_medications" not in existing:
        op.create_table(
            "user_medications",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("name", sa.String(length=120), nullable=False),
            sa.Column("dosage", sa.String(length=50), nullable=False),
            sa.Column("usage_count", sa.Integer(), nullable=False),
            sa.Column("effectiveness_pct", sa.Float(), nullable=False),
        )
        op.create_index("ix_user_medications_id", "user_medications", ["id"])
        op.create_index("ix_user_medications_user_id", "user_medications", ["user_id"])

    if "user_settings" not in existing:
        op.create_table(
            "user_settings",
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("work_schedule", sa.String(length=32), nullable=False),
            sa.Column("daily_reminder_enabled", sa.Boolean(), nullable=False),
            sa.Column("daily_reminder_time", sa.String(length=5), nullable=False),
            sa.Column("risk_alert_enabled", sa.Boolean(), nullable=False),
            sa.Column("medication_reminder_enabled", sa.Boolean(), nullable=False),
            sa.Column("medication_reminder_time", sa.String(length=5), nullable=False),
            sa.Column("theme", sa.String(length=16), nullable=False),
        )

    if "user_supplements" not in existing:
        op.create_table(
            "user_supplements",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("name", sa.String(length=120), nullable=False),
            sa.Column("intake_time", sa.String(length=5), nullable=False),
        )
        op.create_index("ix_user_supplements_id", "user_supplements", ["id"])
        op.create_index("ix_user_supplements_user_id", "user_supplements", ["user_id"])


def downgrade() -> None:
    op.drop_table("user_supplements")
    op.drop_table("user_settings")
    op.drop_table("user_medications")
