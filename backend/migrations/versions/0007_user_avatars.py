"""Store profile photos.

Revision ID: 0007_user_avatars
Revises: 0006_password_sessions
"""

import sqlalchemy as sa
from alembic import op

revision = "0007_user_avatars"
down_revision = "0006_password_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_avatars",
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("content_type", sa.String(length=32), nullable=False),
        sa.Column("data", sa.LargeBinary(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table("user_avatars")
