"""predictions

Revision ID: 0005_predictions
Revises: 0004_weather_observations
Create Date: 2026-11-09
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0005_predictions"
down_revision: Union[str, None] = "0004_weather_observations"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

FEATURE_COLUMNS = [
    "stress",
    "excess_sleep",
    "lack_of_sleep",
    "exercise_trigger",
    "no_exercise_trigger",
    "physical_fatigue",
    "menstrual_phase",
    "ovulation_phase",
    "excessive_emotional_change",
    "weather_change",
    "excessive_sunlight",
    "noise",
    "poor_lighting",
    "specific_smell",
    "excessive_alcohol",
    "irregular_meals",
    "overeating",
    "excessive_caffeine",
    "excessive_smoking",
    "cheese_chocolate",
    "travel",
    "other_trigger",
    "days_since_last_attack",
    "attacks_last_7_records",
]


def upgrade() -> None:
    op.create_table(
        "predictions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        *[sa.Column(name, sa.SmallInteger(), nullable=False) for name in FEATURE_COLUMNS],
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column(
            "weather_observation_id",
            sa.Integer(),
            sa.ForeignKey("weather_observations.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("probability", sa.Float(), nullable=False),
    )
    op.create_index("ix_predictions_user_id", "predictions", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_predictions_user_id", table_name="predictions")
    op.drop_table("predictions")
