import pytest
import respx
from httpx import AsyncClient, Response

from brickfinder.errors import AppError
from brickfinder.schemas.common import ErrorCode
from brickfinder.upstream.rebrickable import RebrickableClient


@pytest.mark.asyncio
async def test_search_parts_happy_path():
    async with respx.mock(base_url="https://example.com") as router:
        router.get("/api/v3/lego/parts/").mock(
            return_value=Response(
                200,
                json={
                    "count": 1,
                    "results": [
                        {
                            "part_num": "3001",
                            "name": "Brick 2x4",
                            "thumbnail_url": "https://img.example.com/3001.png",
                        }
                    ],
                },
            )
        )
        async with AsyncClient() as http:
            client = RebrickableClient(
                http=http, base_url="https://example.com",
                api_key="test-key", timeout=5.0,
            )
            result = await client.search_parts(query="3001")

    assert result.count == 1
    assert result.results[0].part_num == "3001"
    assert result.results[0].name == "Brick 2x4"


@pytest.mark.asyncio
async def test_search_parts_429_raises_rate_limited():
    async with respx.mock(base_url="https://example.com") as router:
        router.get("/api/v3/lego/parts/").mock(return_value=Response(429))
        async with AsyncClient() as http:
            client = RebrickableClient(
                http=http, base_url="https://example.com",
                api_key="test-key", timeout=5.0,
            )
            with pytest.raises(AppError) as ei:
                await client.search_parts(query="3001")
    assert ei.value.code == ErrorCode.RATE_LIMITED
