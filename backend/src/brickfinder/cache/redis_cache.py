from __future__ import annotations

import hashlib
import json
from typing import Any, Protocol

RECOG_IMG_PREFIX = "recog:img:"
RECOG_TTL_SECONDS = 7 * 24 * 3600


def hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def hash_text(text: str) -> str:
    return hash_bytes(text.encode("utf-8"))


class _RedisLike(Protocol):
    async def get(self, key: str) -> bytes | None: ...
    async def set(self, key: str, value: Any, ex: int | None = None) -> Any: ...


class RedisCache:
    def __init__(self, redis: _RedisLike) -> None:
        self._redis = redis

    async def get_json(self, key: str) -> Any | None:
        raw = await self._redis.get(key)
        if raw is None:
            return None
        return json.loads(raw)

    async def set_json(self, key: str, value: Any, *, ttl_seconds: int | None) -> None:
        payload = json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")
        await self._redis.set(key, payload, ex=ttl_seconds)
