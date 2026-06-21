from datetime import UTC, datetime

import pytest
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from brickfinder.cache.redis_cache import RECOG_IMG_PREFIX, RedisCache, hash_bytes
from brickfinder.colors.table import ColorTable
from brickfinder.db.models import ApiCallLog, Base
from brickfinder.errors import AppError
from brickfinder.quota.rate_limit import RateLimiter
from brickfinder.schemas.common import ErrorCode
from brickfinder.services.recognize import RecognizeService
from brickfinder.upstream.brickognize import BrickognizeResult


class FakeRedis:
    def __init__(self) -> None:
        self.store: dict[str, tuple[bytes, int | None]] = {}

    async def get(self, key: str) -> bytes | None:
        return self.store.get(key, (None, None))[0]

    async def set(self, key: str, value: bytes, ex: int | None = None) -> None:
        self.store[key] = (value, ex)


class FakeBrickognize:
    def __init__(
        self, result: BrickognizeResult | None = None, exc: BaseException | None = None
    ) -> None:
        self.result = result
        self.exc = exc
        self.calls: list[tuple[bytes, str, str]] = []

    async def predict_parts(
        self, *, image_bytes: bytes, filename: str, content_type: str
    ) -> BrickognizeResult:
        self.calls.append((image_bytes, filename, content_type))
        if self.exc is not None:
            raise self.exc
        assert self.result is not None
        return self.result


@pytest.fixture
def color_table():
    return ColorTable.from_dict(
        {
            "colors": [
                {"id": 4, "name": "Red", "aliases": ["red"]},
                {"id": 14, "name": "Yellow", "aliases": ["yellow"]},
            ]
        }
    )


@pytest.fixture
async def sm():
    engine: AsyncEngine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield async_sessionmaker(engine, expire_on_commit=False)
    await engine.dispose()


def _now() -> datetime:
    return datetime(2026, 6, 21, 12, 0, tzinfo=UTC)


@pytest.mark.asyncio
async def test_recognize_aggregates_same_part_color(sm, color_table):
    bk = FakeBrickognize(
        BrickognizeResult.model_validate(
            {
                "items": [
                    {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.9},
                    {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.7},
                    {"id": "3001", "name": "Brick 2x4", "color": "Yellow", "score": 0.8},
                ]
            }
        )
    )
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    svc = RecognizeService(
        brickognize=bk,
        cache=cache,
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        resp = await svc.recognize(
            s,
            image_bytes=b"img",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()

    assert resp.cache_hit is False
    parts = {(p.part_num, p.color_id): p for p in resp.parts}
    assert parts[("3001", 4)].quantity == 2
    assert parts[("3001", 4)].confidence == pytest.approx(0.8, rel=1e-3)
    assert parts[("3001", 14)].quantity == 1


@pytest.mark.asyncio
async def test_unknown_color_becomes_minus_one(sm, color_table):
    bk = FakeBrickognize(
        BrickognizeResult.model_validate(
            {"items": [{"id": "3001", "color": "Magenta", "score": 0.5}]}
        )
    )
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    svc = RecognizeService(
        brickognize=bk,
        cache=cache,
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        resp = await svc.recognize(
            s,
            image_bytes=b"img",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()
    assert resp.parts[0].color_id == -1
    assert resp.low_confidence_count == 1


@pytest.mark.asyncio
async def test_cache_hit_skips_upstream(sm, color_table):
    cache_redis = FakeRedis()
    cached_payload = {
        "parts": [{"part_num": "3001", "color_id": 4, "quantity": 5, "confidence": 0.9}],
        "low_confidence_count": 0,
    }
    import json as _j

    cache_redis.store[RECOG_IMG_PREFIX + hash_bytes(b"img")] = (
        _j.dumps(cached_payload).encode(),
        None,
    )
    bk = FakeBrickognize()  # no result; should not be called
    svc = RecognizeService(
        brickognize=bk,
        cache=RedisCache(cache_redis),  # type: ignore[arg-type]
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        resp = await svc.recognize(
            s,
            image_bytes=b"img",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()
    assert resp.cache_hit is True
    assert bk.calls == []
    assert resp.parts[0].quantity == 5


@pytest.mark.asyncio
async def test_rate_limit_raises(sm, color_table):
    bk = FakeBrickognize(BrickognizeResult.model_validate({"items": []}))
    svc = RecognizeService(
        brickognize=bk,
        cache=RedisCache(FakeRedis()),  # type: ignore[arg-type]
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=1,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        await svc.recognize(
            s,
            image_bytes=b"a",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        with pytest.raises(AppError) as ei:
            await svc.recognize(
                s,
                image_bytes=b"b",
                filename="b.jpg",
                content_type="image/jpeg",
                client_key="ip:1",
                now=_now(),
            )
    assert ei.value.code == ErrorCode.RATE_LIMITED


@pytest.mark.asyncio
async def test_api_call_log_written_on_success(sm, color_table):
    bk = FakeBrickognize(BrickognizeResult.model_validate({"items": []}))
    svc = RecognizeService(
        brickognize=bk,
        cache=RedisCache(FakeRedis()),  # type: ignore[arg-type]
        colors=color_table,
        rate_limiter=RateLimiter(),
        recognize_limit_per_day=100,
        low_confidence_threshold=0.6,
    )
    async with sm() as s:
        await svc.recognize(
            s,
            image_bytes=b"x",
            filename="a.jpg",
            content_type="image/jpeg",
            client_key="ip:1",
            now=_now(),
        )
        await s.commit()
        rows = (await s.execute(__import__("sqlalchemy").select(ApiCallLog))).scalars().all()
    assert len(rows) == 1
    assert rows[0].route == "recognize"
    assert rows[0].cache_hit is False
