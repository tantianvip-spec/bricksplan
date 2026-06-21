from __future__ import annotations

import httpx
from pydantic import BaseModel

from ..errors import AppError
from ..logging import get_logger
from ..schemas.common import ErrorCode
from .breaker import CircuitBreaker

log = get_logger(__name__)

_PATH = "/predict/parts/"
_MAX_ATTEMPTS = 2  # initial + 1 retry


class BrickognizeRawItem(BaseModel):
    id: str
    name: str | None = None
    color: str | None = None
    score: float | None = None


class BrickognizeResult(BaseModel):
    items: list[BrickognizeRawItem]


class BrickognizeClient:
    def __init__(
        self,
        *,
        http: httpx.AsyncClient,
        base_url: str,
        timeout: float,
        breaker: CircuitBreaker,
    ) -> None:
        self._http = http
        self._base = base_url.rstrip("/")
        self._timeout = timeout
        self._breaker = breaker

    async def predict_parts(
        self, *, image_bytes: bytes, filename: str, content_type: str
    ) -> BrickognizeResult:
        if not self._breaker.allow():
            log.warning("brickognize_breaker_open")
            raise AppError(
                code=ErrorCode.UPSTREAM_ERROR,
                message="Recognition service unavailable",
                http_status=502,
            )

        last_exc: BaseException | None = None
        for attempt in range(_MAX_ATTEMPTS):
            try:
                files = {"query_image": (filename, image_bytes, content_type)}
                resp = await self._http.post(
                    f"{self._base}{_PATH}", files=files, timeout=self._timeout
                )
                if resp.status_code >= 500:
                    last_exc = httpx.HTTPStatusError(
                        f"{resp.status_code}", request=resp.request, response=resp
                    )
                    log.warning(
                        "brickognize_5xx", status=resp.status_code, attempt=attempt
                    )
                    continue
                resp.raise_for_status()
                payload = resp.json()
                self._breaker.record_success()
                return BrickognizeResult.model_validate(payload)
            except httpx.TimeoutException as exc:
                last_exc = exc
                log.warning("brickognize_timeout", attempt=attempt)
                continue
            except httpx.HTTPError as exc:
                last_exc = exc
                log.warning("brickognize_http_error", attempt=attempt, error=repr(exc))
                continue

        self._breaker.record_failure()
        if isinstance(last_exc, httpx.TimeoutException):
            raise AppError(
                code=ErrorCode.UPSTREAM_TIMEOUT,
                message="Recognition service timed out",
                http_status=504,
            )
        raise AppError(
            code=ErrorCode.UPSTREAM_ERROR,
            message="Recognition service error",
            http_status=502,
        )
