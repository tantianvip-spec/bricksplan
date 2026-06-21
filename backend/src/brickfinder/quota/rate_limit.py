from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from ..db.models import RateQuota
from ..errors import AppError
from ..schemas.common import ErrorCode

_ROUTE_COLUMNS = {
    "recognize": "recognize_count",
    "match": "match_count",
    "translate": "translate_count",
}

_WINDOW = timedelta(hours=24)


def _naive_utc(dt: datetime) -> datetime:
    """Normalize aware or naive datetime to naive UTC.

    SQLite drops timezone info from DateTime columns, so production (Postgres)
    returns aware datetimes while unit tests using SQLite return naive ones.
    """
    if dt.tzinfo is not None:
        return dt.astimezone(UTC).replace(tzinfo=None)
    return dt


class RateLimiter:
    async def check_and_bump(
        self,
        session: AsyncSession,
        *,
        client_key: str,
        route: str,
        limit_per_day: int,
        now: datetime,
    ) -> int:
        if route not in _ROUTE_COLUMNS:
            raise ValueError(f"unknown route: {route}")
        column = _ROUTE_COLUMNS[route]

        now_naive = _naive_utc(now)
        row = await session.get(RateQuota, client_key)
        if row is None:
            row = RateQuota(
                client_key=client_key,
                recognize_count=0,
                match_count=0,
                translate_count=0,
                window_start=now_naive,
            )
            session.add(row)
            await session.flush()
        elif now_naive - _naive_utc(row.window_start) >= _WINDOW:
            row.recognize_count = 0
            row.match_count = 0
            row.translate_count = 0
            row.window_start = now_naive

        current: int = getattr(row, column)
        if current >= limit_per_day:
            reset_at = _naive_utc(row.window_start) + _WINDOW
            retry = max(int((reset_at - now_naive).total_seconds()), 1)
            raise AppError(
                code=ErrorCode.RATE_LIMITED,
                message="Daily quota exceeded",
                http_status=429,
                retry_after_seconds=retry,
            )

        setattr(row, column, current + 1)
        await session.flush()
        return current + 1
