import io

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession

from brickfinder.config import Settings
from brickfinder.deps import (
    get_client_key,
    get_db_session,
    get_recognize_service,
    get_settings_dep,
)
from brickfinder.main import create_app
from brickfinder.schemas.recognize import PartItem, RecognizeResponse


class FakeSession:
    async def commit(self) -> None:
        pass


class FakeService:
    async def recognize(self, session: AsyncSession, **kwargs) -> RecognizeResponse:
        return RecognizeResponse(
            parts=[PartItem(part_num="3001", color_id=4, quantity=1, confidence=0.9)],
            cache_hit=False,
            low_confidence_count=0,
        )


@pytest.fixture
def client():
    app = create_app()
    app.dependency_overrides[get_db_session] = lambda: FakeSession()
    app.dependency_overrides[get_recognize_service] = lambda: FakeService()
    app.dependency_overrides[get_client_key] = lambda: "ip:1"
    app.dependency_overrides[get_settings_dep] = lambda: Settings(
        database_url="postgresql+asyncpg://x",
        redis_url="redis://x",
        upload_max_bytes=1024 * 1024,
    )  # type: ignore[call-arg]
    yield TestClient(app, raise_server_exceptions=False)
    app.dependency_overrides.clear()


def test_recognize_valid_image(client):
    files = {"image": ("a.png", io.BytesIO(b"\x89PNG\r\n\x1a\n"), "image/png")}
    r = client.post("/v1/recognize", files=files)
    assert r.status_code == 200
    body = r.json()
    assert body["cache_hit"] is False
    assert body["parts"][0]["part_num"] == "3001"


def test_recognize_rejects_non_image(client):
    files = {"image": ("a.txt", io.BytesIO(b"hello"), "text/plain")}
    r = client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    assert r.json()["code"] == "INVALID_INPUT"


def test_recognize_rejects_empty_image(client):
    files = {"image": ("a.png", io.BytesIO(b""), "image/png")}
    r = client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    assert r.json()["code"] == "INVALID_INPUT"


def test_recognize_rejects_oversized_image(client):
    big = b"\x89PNG\r\n\x1a\n" + b"\x00" * (2 * 1024 * 1024)
    files = {"image": ("big.png", io.BytesIO(big), "image/png")}
    r = client.post("/v1/recognize", files=files)
    assert r.status_code == 400
    assert r.json()["code"] == "INVALID_INPUT"
