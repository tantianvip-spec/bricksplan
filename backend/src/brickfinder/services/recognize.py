from __future__ import annotations

import time
from collections import defaultdict
from datetime import datetime
from typing import Protocol

from sqlalchemy.ext.asyncio import AsyncSession

from ..cache.redis_cache import (
    RECOG_IMG_PREFIX,
    RECOG_TTL_SECONDS,
    RedisCache,
    hash_bytes,
)
from ..colors.table import ColorTable
from ..db.models import ApiCallLog
from ..errors import AppError
from ..logging import get_logger
from ..quota.rate_limit import RateLimiter
from ..schemas.recognize import PartItem, RecognizeResponse
from ..upstream.brickognize import BrickognizeResult

log = get_logger(__name__)


class _BrickognizeLike(Protocol):
    async def predict_parts(
        self, *, image_bytes: bytes, filename: str, content_type: str
    ) -> BrickognizeResult: ...


class RecognizeService:
    def __init__(
        self,
        *,
        brickognize: _BrickognizeLike,
        cache: RedisCache,
        colors: ColorTable,
        rate_limiter: RateLimiter,
        recognize_limit_per_day: int,
        low_confidence_threshold: float = 0.6,
    ) -> None:
        self._brickognize = brickognize
        self._cache = cache
        self._colors = colors
        self._rate_limiter = rate_limiter
        self._limit = recognize_limit_per_day
        self._low_conf = low_confidence_threshold

    async def recognize(
        self,
        session: AsyncSession,
        *,
        image_bytes: bytes,
        filename: str,
        content_type: str,
        client_key: str,
        now: datetime,
    ) -> RecognizeResponse:
        started = time.monotonic()
        upstream_status: int | None = None
        cache_hit = False

        try:
            await self._rate_limiter.check_and_bump(
                session,
                client_key=client_key,
                route="recognize",
                limit_per_day=self._limit,
                now=now,
            )

            digest = hash_bytes(image_bytes)
            cache_key = RECOG_IMG_PREFIX + digest
            cached = await self._cache.get_json(cache_key)
            if cached is not None:
                cache_hit = True
                return RecognizeResponse(
                    parts=[PartItem(**p) for p in cached["parts"]],
                    cache_hit=True,
                    low_confidence_count=int(cached.get("low_confidence_count", 0)),
                )

            result = await self._brickognize.predict_parts(
                image_bytes=image_bytes, filename=filename, content_type=content_type
            )
            upstream_status = 200

            parts = self._normalize(result)
            low_conf = sum(
                1 for p in parts if p.confidence is not None and p.confidence < self._low_conf
            )

            await self._cache.set_json(
                cache_key,
                {
                    "parts": [p.model_dump() for p in parts],
                    "low_confidence_count": low_conf,
                },
                ttl_seconds=RECOG_TTL_SECONDS,
            )
            return RecognizeResponse(parts=parts, cache_hit=False, low_confidence_count=low_conf)

        except AppError as exc:
            upstream_status = exc.http_status if exc.http_status >= 500 else None
            raise
        finally:
            session.add(
                ApiCallLog(
                    route="recognize",
                    cache_hit=cache_hit,
                    upstream_status=upstream_status,
                    latency_ms=int((time.monotonic() - started) * 1000),
                )
            )

    def _normalize(self, result: BrickognizeResult) -> list[PartItem]:
        groups: dict[tuple[str, int], list[float]] = defaultdict(list)
        for item in result.items:
            color_id = self._colors.lookup(item.color or "")
            key = (item.id, color_id)
            if item.score is not None:
                groups[key].append(item.score)
            else:
                groups[key].append(0.0)
        parts: list[PartItem] = []
        for (part_num, color_id), scores in groups.items():
            avg = sum(scores) / len(scores) if scores else None
            parts.append(
                PartItem(
                    part_num=part_num,
                    color_id=color_id,
                    quantity=len(scores),
                    confidence=avg,
                )
            )
        parts.sort(key=lambda p: (p.part_num, p.color_id))
        return parts
