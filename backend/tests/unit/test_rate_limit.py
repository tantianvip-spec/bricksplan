from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from brickfinder.db.models import Base, RateQuota
from brickfinder.errors import AppError
from brickfinder.quota.rate_limit import RateLimiter
from brickfinder.schemas.common import ErrorCode


@pytest.fixture
async def sm():
    engine: AsyncEngine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False)
    await engine.dispose()


@pytest.mark.asyncio
async def test_first_call_creates_row_and_returns_one(sm):
    rl = RateLimiter()
    now = datetime(2026, 6, 21, 12, 0, tzinfo=UTC)
    async with sm() as s:
        count = await rl.check_and_bump(
            s, client_key="ip:1.2.3.4", route="recognize", limit_per_day=10, now=now
        )
        await s.commit()
    assert count == 1


@pytest.mark.asyncio
async def test_under_limit_increments(sm):
    rl = RateLimiter()
    now = datetime(2026, 6, 21, 12, 0, tzinfo=UTC)
    async with sm() as s:
        for _ in range(3):
            await rl.check_and_bump(s, client_key="k", route="recognize", limit_per_day=10, now=now)
        await s.commit()
        row = await s.get(RateQuota, "k")
        assert row is not None
        assert row.recognize_count == 3


@pytest.mark.asyncio
async def test_over_limit_raises(sm):
    rl = RateLimiter()
    now = datetime(2026, 6, 21, 12, 0, tzinfo=UTC)
    async with sm() as s:
        for _ in range(2):
            await rl.check_and_bump(s, client_key="k", route="recognize", limit_per_day=2, now=now)
        await s.commit()
        with pytest.raises(AppError) as ei:
            await rl.check_and_bump(
                s, client_key="k", route="recognize", limit_per_day=2, now=now
            )
        assert ei.value.code == ErrorCode.RATE_LIMITED
        assert ei.value.retry_after_seconds is not None
        assert ei.value.retry_after_seconds > 0


@pytest.mark.asyncio
async def test_window_resets_after_24h(sm):
    rl = RateLimiter()
    t0 = datetime(2026, 6, 21, 12, 0, tzinfo=UTC)
    async with sm() as s:
        for _ in range(5):
            await rl.check_and_bump(s, client_key="k", route="recognize", limit_per_day=5, now=t0)
        await s.commit()

        t1 = t0 + timedelta(hours=24, seconds=1)
        count = await rl.check_and_bump(
            s, client_key="k", route="recognize", limit_per_day=5, now=t1
        )
        await s.commit()
        assert count == 1
