from __future__ import annotations

from collections.abc import AsyncIterator
from datetime import UTC, datetime
from functools import lru_cache

import httpx
from fastapi import Depends, Request
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from .cache.redis_cache import RedisCache
from .colors.table import ColorTable, load_default
from .config import Settings, get_settings
from .db.engine import create_engine_and_sessionmaker
from .quota.rate_limit import RateLimiter
from .services.recognize import RecognizeService
from .upstream.breaker import CircuitBreaker
from .upstream.brickognize import BrickognizeClient


@lru_cache(maxsize=1)
def _engine_and_sm() -> async_sessionmaker[AsyncSession]:
    _, sm = create_engine_and_sessionmaker(get_settings().database_url)
    return sm


@lru_cache(maxsize=1)
def _redis() -> Redis[bytes]:
    return Redis.from_url(get_settings().redis_url, decode_responses=False)


@lru_cache(maxsize=1)
def _http() -> httpx.AsyncClient:
    return httpx.AsyncClient()


@lru_cache(maxsize=1)
def _breaker() -> CircuitBreaker:
    s = get_settings()
    return CircuitBreaker(
        threshold=s.circuit_breaker_threshold,
        cooldown_seconds=s.circuit_breaker_cooldown_seconds,
    )


@lru_cache(maxsize=1)
def _colors() -> ColorTable:
    return load_default()


@lru_cache(maxsize=1)
def _rate_limiter() -> RateLimiter:
    return RateLimiter()


async def get_db_session() -> AsyncIterator[AsyncSession]:
    sm = _engine_and_sm()
    async with sm() as session:
        yield session


def get_settings_dep() -> Settings:
    return get_settings()


def get_recognize_service(
    settings: Settings = Depends(get_settings_dep),
) -> RecognizeService:
    client = BrickognizeClient(
        http=_http(),
        base_url=settings.brickognize_base_url,
        timeout=settings.brickognize_timeout_seconds,
        breaker=_breaker(),
    )
    return RecognizeService(
        brickognize=client,
        cache=RedisCache(_redis()),
        colors=_colors(),
        rate_limiter=_rate_limiter(),
        recognize_limit_per_day=settings.rate_limit_recognize_per_day,
    )


def get_client_key(request: Request) -> str:
    header = request.headers.get("X-Client-Id")
    if header:
        return f"dev:{header[:64]}"
    host = request.client.host if request.client else "unknown"
    return f"ip:{host}"


def utcnow() -> datetime:
    return datetime.now(tz=UTC)
