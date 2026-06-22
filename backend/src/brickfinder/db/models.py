from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class RateQuota(Base):
    __tablename__ = "rate_quota"

    client_key: Mapped[str] = mapped_column(String, primary_key=True)
    recognize_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    match_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    translate_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=False), nullable=False)


class ApiCallLog(Base):
    __tablename__ = "api_call_log"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    ts: Mapped[datetime] = mapped_column(
        DateTime(timezone=False), nullable=False, server_default=func.now()
    )
    route: Mapped[str] = mapped_column(String, nullable=False)
    cache_hit: Mapped[bool] = mapped_column(Boolean, nullable=False)
    upstream_status: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latency_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
