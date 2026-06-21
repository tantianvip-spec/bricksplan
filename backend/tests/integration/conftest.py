from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator, Iterator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import create_async_engine
from testcontainers.postgres import PostgresContainer
from testcontainers.redis import RedisContainer

from brickfinder.config import get_settings
from brickfinder.db.models import Base


@pytest.fixture(scope="session")
def postgres() -> Iterator[PostgresContainer]:
    with PostgresContainer("postgres:16-alpine") as pg:
        yield pg


@pytest.fixture(scope="session")
def redis_container() -> Iterator[RedisContainer]:
    with RedisContainer("redis:7-alpine") as r:
        yield r


@pytest.fixture(scope="session", autouse=True)
def configure_env(postgres, redis_container, monkeypatch_session) -> None:
    raw = postgres.get_connection_url()
    # testcontainers returns psycopg2 url; convert to asyncpg
    url = raw.replace("postgresql+psycopg2://", "postgresql+asyncpg://").replace(
        "postgresql://", "postgresql+asyncpg://"
    )
    redis_url = f"redis://{redis_container.get_container_host_ip()}:{redis_container.get_exposed_port(6379)}/0"

    monkeypatch_session.setenv("DATABASE_URL", url)
    monkeypatch_session.setenv("REDIS_URL", redis_url)
    monkeypatch_session.setenv("BRICKOGNIZE_BASE_URL", "http://brickognize.test")
    monkeypatch_session.setenv("BRICKOGNIZE_TIMEOUT_SECONDS", "2")
    monkeypatch_session.setenv("RATE_LIMIT_RECOGNIZE_PER_DAY", "100")
    monkeypatch_session.setenv("UPLOAD_MAX_BYTES", str(1024 * 1024))
    get_settings.cache_clear()


@pytest.fixture(scope="session")
def monkeypatch_session() -> Iterator[pytest.MonkeyPatch]:
    mp = pytest.MonkeyPatch()
    yield mp
    mp.undo()


@pytest_asyncio.fixture(scope="session", autouse=True)
async def create_schema(configure_env) -> AsyncIterator[None]:
    settings = get_settings()
    engine = create_async_engine(settings.database_url)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    await engine.dispose()
    yield


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    # Import here so env is already set.
    from brickfinder.main import create_app

    app = create_app()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()
