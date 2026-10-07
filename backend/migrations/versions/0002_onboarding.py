"""Persist first-login onboarding on the account.

Revision ID: 0002_onboarding
Revises: 0001_initial
"""

import sqlalchemy as sa
from alembic import op

revision = "0002_onboarding"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("onboarding_step", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "users",
        sa.Column(
            "onboarding_completed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    with op.batch_alter_table("users") as batch:
        batch.create_check_constraint(
            "ck_users_onboarding_step", "onboarding_step BETWEEN 0 AND 1"
        )
    # People who already use the diary continue straight to the app.
    op.execute(
        sa.text("""
        UPDATE users SET onboarding_step = 1, onboarding_completed = true
        WHERE EXISTS (SELECT 1 FROM attacks WHERE attacks.user_id = users.id)
           OR EXISTS (SELECT 1 FROM diary_entries WHERE diary_entries.user_id = users.id)
    """)
    )


def downgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.drop_constraint("ck_users_onboarding_step", type_="check")
        batch.drop_column("onboarding_completed")
        batch.drop_column("onboarding_step")
