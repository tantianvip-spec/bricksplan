"""initial

Revision ID: 0001
Revises:
Create Date: 2026-06-21

"""
from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "rate_quota",
        sa.Column("client_key", sa.String(), primary_key=True),
        sa.Column("recognize_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("match_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("translate_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("window_start", sa.DateTime(timezone=False), nullable=False),
    )
    op.create_table(
        "api_call_log",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "ts", sa.DateTime(timezone=False), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("route", sa.String(), nullable=False),
        sa.Column("cache_hit", sa.Boolean(), nullable=False),
        sa.Column("upstream_status", sa.Integer(), nullable=True),
        sa.Column("latency_ms", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("api_call_log")
    op.drop_table("rate_quota")
