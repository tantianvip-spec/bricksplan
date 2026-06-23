"""fix timezone columns to naive UTC

Revision ID: 0002
Revises: 0001
Create Date: 2026-06-23

"""
from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("rate_quota", "window_start",
        type_=sa.DateTime(timezone=False),
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
        postgresql_using='window_start AT TIME ZONE \'UTC\'',
    )
    op.alter_column("api_call_log", "ts",
        type_=sa.DateTime(timezone=False),
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.func.now(),
        postgresql_using='ts AT TIME ZONE \'UTC\'',
    )


def downgrade() -> None:
    op.alter_column("api_call_log", "ts",
        type_=sa.DateTime(timezone=True),
        existing_type=sa.DateTime(timezone=False),
        nullable=False,
        server_default=sa.func.now(),
    )
    op.alter_column("rate_quota", "window_start",
        type_=sa.DateTime(timezone=True),
        existing_type=sa.DateTime(timezone=False),
        nullable=False,
    )
