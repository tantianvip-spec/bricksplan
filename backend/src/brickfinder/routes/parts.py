from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from ..cache.redis_cache import RedisCache, hash_text
from ..config import Settings
from ..deps import (
    _http,
    _rate_limiter,
    _redis,
    get_client_key,
    get_db_session,
    get_settings_dep,
    utcnow,
)
from ..upstream.rebrickable import RebrickableClient

router = APIRouter(prefix="/v1")

_SEARCH_CACHE_PREFIX = "parts:search:"
_SEARCH_CACHE_TTL = 24 * 3600


@router.get("/parts/search")
async def search_parts(
    q: str = Query(..., min_length=1, max_length=50),
    settings: Settings = Depends(get_settings_dep),
    client_key: str = Depends(get_client_key),
    session: AsyncSession = Depends(get_db_session),
) -> dict[str, object]:
    await _rate_limiter().check_and_bump(
        session,
        client_key=client_key,
        route="recognize",
        limit_per_day=settings.rate_limit_parts_search_per_day,
        now=utcnow(),
    )

    cache_key = _SEARCH_CACHE_PREFIX + hash_text(q)
    cache = RedisCache(_redis())
    cached = await cache.get_json(cache_key)
    if cached is not None:
        return {"results": cached, "cached": True}

    client = RebrickableClient(
        http=_http(),
        base_url="https://rebrickable.com",
        api_key=settings.rebrickable_api_key,
        timeout=settings.rebrickable_timeout_seconds,
    )
    result = await client.search_parts(query=q)

    payload: list[dict[str, object]] = [
        {
            "part_num": r.part_num,
            "name": r.name,
            "thumbnail_url": r.thumbnail_url,
        }
        for r in result.results
    ]

    await cache.set_json(cache_key, payload, ttl_seconds=_SEARCH_CACHE_TTL)

    return {"results": payload, "cached": False}
