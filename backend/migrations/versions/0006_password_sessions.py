"""Invalidate existing sessions when a password is changed."""
import sqlalchemy as sa
from alembic import op

revision = "0006_password_sessions"
down_revision = "0005_wellness_tables"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("token_version", sa.Integer(), nullable=False, server_default=sa.text("0")))


def downgrade() -> None:
    op.drop_column("users", "token_version")
