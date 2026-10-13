"""merge_heads

Revision ID: 3ebcaabbf2f4
Revises: 0002_onboarding, 0e572476098e
Create Date: 2026-10-07 18:20:36.387891
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '3ebcaabbf2f4'
down_revision: Union[str, None] = ('0002_onboarding', '0e572476098e')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
