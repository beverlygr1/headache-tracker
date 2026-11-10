"""Join the dev and weather prediction migration histories."""

revision = "0008_merge_weather_predictions"
down_revision = ("0007_user_avatars", "0005_predictions")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
