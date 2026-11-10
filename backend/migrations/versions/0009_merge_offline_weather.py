"""Join the offline attack and weather forecast migration histories."""

revision = "0009_merge_offline_weather"
down_revision = ("0008_merge_weather_predictions", "0008_offline_medication_effects")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
