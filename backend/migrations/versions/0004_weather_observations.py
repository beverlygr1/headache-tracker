"""weather observations

Revision ID: 0004_weather_observations
Revises: 0003_diary_headache
Create Date: 2026-11-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0004_weather_observations"
down_revision: Union[str, None] = "0003_diary_headache"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "weather_observations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("local_date", sa.Date(), nullable=False),
        sa.Column("timezone", sa.String(length=64), nullable=False),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("fetched_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("mean_pressure_msl_today", sa.Float(), nullable=False),
        sa.Column("mean_pressure_msl_prev", sa.Float(), nullable=False),
        sa.Column("mean_temperature_today", sa.Float(), nullable=False),
        sa.Column("mean_temperature_prev", sa.Float(), nullable=False),
        sa.Column("delta_pressure_hpa", sa.Float(), nullable=False),
        sa.Column("delta_temperature_c", sa.Float(), nullable=False),
        sa.Column("pressure_level", sa.SmallInteger(), nullable=False),
        sa.Column("temperature_level", sa.SmallInteger(), nullable=False),
        sa.Column("weather_change_level", sa.SmallInteger(), nullable=False),
        sa.Column("raw_hourly", sa.JSON(), nullable=False),
        sa.CheckConstraint("pressure_level BETWEEN 0 AND 2", name="ck_weather_pressure_level"),
        sa.CheckConstraint("temperature_level BETWEEN 0 AND 2", name="ck_weather_temperature_level"),
        sa.CheckConstraint("weather_change_level BETWEEN 0 AND 2", name="ck_weather_change_level"),
    )


def downgrade() -> None:
    op.drop_table("weather_observations")
