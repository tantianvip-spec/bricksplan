import io

import pytest
import respx
from httpx import Response

pytestmark = pytest.mark.integration


def _png_bytes(size: int = 1024) -> bytes:
    # Minimal valid PNG header + zero-padded body; FastAPI only checks content-type.
    head = b"\x89PNG\r\n\x1a\n"
    return head + b"\x00" * (size - len(head))


@pytest.mark.asyncio
async def test_recognize_happy_path(client):
    payload = {
        "items": [
            {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.92},
            {"id": "3001", "name": "Brick 2x4", "color": "Red", "score": 0.85},
            {"id": "3003", "name": "Brick 2x2", "color": "Yellow", "score": 0.80},
        ]
    }
    async with respx.mock(base_url="http://brickognize.test") as router:
        router.post("/predict/parts/").mock(return_value=Response(200, json=payload))
        files = {"image": ("a.png", io.BytesIO(_png_bytes()), "image/png")}
        r = await client.post("/v1/recognize", files=files)

    assert r.status_code == 200, r.text
    body = r.json()
    assert body["cache_hit"] is False
    # Red Brick 2x4 should be quantity=2
    red = next(p for p in body["parts"] if p["part_num"] == "3001")
    assert red["quantity"] == 2


@pytest.mark.asyncio
async def test_recognize_rejects_non_image(client):
    files = {"image": ("a.txt", io.BytesIO(b"hello"), "text/plain")}
    r = await client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    body = r.json()
    assert body["code"] == "INVALID_INPUT"


@pytest.mark.asyncio
async def test_recognize_rejects_oversized(client):
    big = b"\x89PNG\r\n\x1a\n" + b"\x00" * (2 * 1024 * 1024)
    files = {"image": ("big.png", io.BytesIO(big), "image/png")}
    r = await client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    assert r.json()["code"] == "INVALID_INPUT"


@pytest.mark.asyncio
async def test_recognize_upstream_500_returns_502(client):
    async with respx.mock(base_url="http://brickognize.test") as router:
        router.post("/predict/parts/").mock(return_value=Response(503))
        files = {"image": ("a.png", io.BytesIO(_png_bytes()), "image/png")}
        r = await client.post("/v1/recognize", files=files)
    assert r.status_code == 502
    assert r.json()["code"] == "UPSTREAM_ERROR"


@pytest.mark.asyncio
async def test_recognize_second_call_hits_cache(client):
    payload = {"items": [{"id": "3001", "color": "Red", "score": 0.9}]}
    body = _png_bytes(2048)

    async with respx.mock(base_url="http://brickognize.test") as router:
        route = router.post("/predict/parts/").mock(return_value=Response(200, json=payload))

        files1 = {"image": ("a.png", io.BytesIO(body), "image/png")}
        r1 = await client.post("/v1/recognize", files=files1)
        assert r1.status_code == 200
        assert r1.json()["cache_hit"] is False

        files2 = {"image": ("a.png", io.BytesIO(body), "image/png")}
        r2 = await client.post("/v1/recognize", files=files2)
        assert r2.status_code == 200
        assert r2.json()["cache_hit"] is True

    assert route.call_count == 1
