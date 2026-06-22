import pytest
import respx
from httpx import AsyncClient, ConnectTimeout, Response

from brickfinder.errors import AppError
from brickfinder.schemas.common import ErrorCode
from brickfinder.upstream.breaker import CircuitBreaker
from brickfinder.upstream.brickognize import BrickognizeClient


@pytest.fixture
def breaker():
    return CircuitBreaker(threshold=3, cooldown_seconds=30)


@pytest.mark.asyncio
async def test_predict_parts_happy_path(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        router.post("/predict/parts/").mock(
            return_value=Response(
                200,
                json={
                    "items": [
                        {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.91},
                        {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.88},
                    ]
                },
            )
        )
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            result = await client.predict_parts(
                image_bytes=b"fake", filename="x.jpg", content_type="image/jpeg"
            )

    assert len(result.items) == 2
    assert result.items[0].id == "3001"


@pytest.mark.asyncio
async def test_upstream_5xx_retries_then_fails(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        route = router.post("/predict/parts/").mock(return_value=Response(503))
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            with pytest.raises(AppError) as ei:
                await client.predict_parts(
                    image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
                )
    assert ei.value.code == ErrorCode.UPSTREAM_ERROR
    assert route.call_count == 2  # initial + 1 retry


@pytest.mark.asyncio
async def test_timeout_returns_upstream_timeout(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        router.post("/predict/parts/").mock(side_effect=ConnectTimeout("slow"))
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            with pytest.raises(AppError) as ei:
                await client.predict_parts(
                    image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
                )
    assert ei.value.code == ErrorCode.UPSTREAM_TIMEOUT


@pytest.mark.asyncio
async def test_malformed_200_returns_upstream_error(breaker):
    async with respx.mock(base_url="https://example.com") as router:
        route = router.post("/predict/parts/").mock(return_value=Response(200, text="not json"))
        async with AsyncClient() as http:
            client = BrickognizeClient(
                http=http, base_url="https://example.com", timeout=5.0, breaker=breaker
            )
            with pytest.raises(AppError) as ei:
                await client.predict_parts(
                    image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
                )
    assert ei.value.code == ErrorCode.UPSTREAM_ERROR
    assert route.call_count == 2  # retried once


@pytest.mark.asyncio
async def test_breaker_open_skips_call():
    cb = CircuitBreaker(threshold=1, cooldown_seconds=30)
    cb.record_failure()  # open

    calls: list[object] = []

    class CapturingAsyncClient(AsyncClient):
        async def request(self, *args, **kwargs):
            calls.append((args, kwargs))
            return Response(200, json={"items": []})

    async with CapturingAsyncClient() as http:
        client = BrickognizeClient(
            http=http, base_url="https://example.com", timeout=5.0, breaker=cb
        )
        with pytest.raises(AppError) as ei:
            await client.predict_parts(
                image_bytes=b"x", filename="x.jpg", content_type="image/jpeg"
            )
    assert ei.value.code == ErrorCode.UPSTREAM_ERROR
    assert calls == []
