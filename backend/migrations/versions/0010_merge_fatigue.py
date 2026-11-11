"""Join physical fatigue and current application migration histories."""
revision = "0010_merge_fatigue"
down_revision = ("0009_merge_offline_weather", "0006_diary_physical_fatigue")
branch_labels = None
depends_on = None

def upgrade() -> None:
    pass

def downgrade() -> None:
    pass
