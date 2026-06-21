import pytest

from brickfinder.cache.redis_cache import (
    RECOG_IMG_PREFIX,
    RECOG_TTL_SECONDS,
    RedisCache,
    hash_bytes,
    hash_text,
)


def test_hash_bytes_stable_and_hex():
    h = hash_bytes(b"hello")
    assert h == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"


def test_hash_text_equals_hash_bytes_utf8():
    assert hash_text("héllo") == hash_bytes("héllo".encode())


class FakeRedis:
    def __init__(self) -> None:
        self.store: dict[str, tuple[bytes, int | None]] = {}

    async def get(self, key: str) -> bytes | None:
        return self.store.get(key, (None, None))[0]

    async def set(self, key: str, value: bytes, ex: int | None = None) -> None:
        self.store[key] = (value, ex)


@pytest.mark.asyncio
async def test_set_and_get_json():
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    await cache.set_json("k", {"parts": [{"part_num": "3001"}]}, ttl_seconds=60)
    got = await cache.get_json("k")
    assert got == {"parts": [{"part_num": "3001"}]}


@pytest.mark.asyncio
async def test_miss_returns_none():
    cache = RedisCache(FakeRedis())  # type: ignore[arg-type]
    assert await cache.get_json("missing") is None


def test_constants():
    assert RECOG_IMG_PREFIX == "recog:img:"
    assert RECOG_TTL_SECONDS == 7 * 24 * 3600
