from __future__ import annotations

import httpx
from pydantic import BaseModel

from ..errors import AppError
from ..logging import get_logger
from ..schemas.common import ErrorCode

log = get_logger(__name__)

_PATH = "/api/v3/lego/parts/"


class RebrickablePartItem(BaseModel):
    part_num: str
    name: str
    thumbnail_url: str | None = None


class RebrickableSearchResult(BaseModel):
    results: list[RebrickablePartItem]
    count: int


class RebrickableClient:
    def __init__(
        self,
        *,
        http: httpx.AsyncClient,
        base_url: str,
        api_key: str,
        timeout: float,
    ) -> None:
        self._http = http
        self._base = base_url.rstrip("/")
        self._api_key = api_key
        self._timeout = timeout

    async def search_parts(self, *, query: str) -> RebrickableSearchResult:
        if not self._api_key:
            raise AppError(
                code=ErrorCode.INTERNAL,
                message="Rebrickable API key not configured",
                http_status=500,
            )

        try:
            resp = await self._http.get(
                f"{self._base}{_PATH}",
                params={"search": query, "page_size": 20},
                headers={"Authorization": f"key {self._api_key}"},
                timeout=self._timeout,
            )
            if resp.status_code == 429:
                raise AppError(
                    code=ErrorCode.RATE_LIMITED,
                    message="Rebrickable rate limit exceeded",
                    http_status=429,
                )
            if resp.status_code >= 500:
                raise AppError(
                    code=ErrorCode.UPSTREAM_ERROR,
                    message="Rebrickable service error",
                    http_status=502,
                )
            resp.raise_for_status()
            data = resp.json()
            return RebrickableSearchResult(
                results=[RebrickablePartItem(**r) for r in data["results"]],
                count=data.get("count", 0),
            )
        except httpx.TimeoutException:
            raise AppError(
                code=ErrorCode.UPSTREAM_TIMEOUT,
                message="Rebrickable timed out",
                http_status=504,
            ) from None
        except httpx.HTTPError as exc:
            log.warning("rebrickable_http_error", error=repr(exc))
            raise AppError(
                code=ErrorCode.UPSTREAM_ERROR,
                message="Rebrickable service error",
                http_status=502,
            ) from exc
