"""Record explicit daily headache presence without inferring missing labels."""

import sqlalchemy as sa
from alembic import op

revision = "0003_diary_headache"
down_revision = "0002_onboarding"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "diary_entries", sa.Column("headache_present", sa.Boolean(), nullable=True)
    )


def downgrade() -> None:
    with op.batch_alter_table("diary_entries") as batch:
        batch.drop_column("headache_present")
