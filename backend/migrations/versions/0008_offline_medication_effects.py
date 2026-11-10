"""Medication outcomes and idempotent attack creation.

Revision ID: 0008_offline_medication_effects
Revises: 0007_user_avatars
"""
from alembic import op
import sqlalchemy as sa

revision = "0008_offline_medication_effects"
down_revision = "0007_user_avatars"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("attacks") as batch:
        batch.add_column(sa.Column("medication_effects", sa.JSON(), server_default=sa.text("'{}'"), nullable=False))
        batch.add_column(sa.Column("client_request_id", sa.String(36), nullable=True))
        batch.add_column(sa.Column("client_payload_hash", sa.String(64), nullable=True))
        batch.create_unique_constraint("uq_attack_client_request", ["user_id", "client_request_id"])


def downgrade() -> None:
    with op.batch_alter_table("attacks") as batch:
        batch.drop_constraint("uq_attack_client_request", type_="unique")
        batch.drop_column("client_payload_hash")
        batch.drop_column("client_request_id")
        batch.drop_column("medication_effects")
