from fastapi.testclient import TestClient

from brickfinder import app

client = TestClient(app)


def test_health_returns_ok():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_root_returns_version():
    r = client.get("/")
    assert r.status_code == 200
    body = r.json()
    assert body["message"] == "brickfinder hello-world"
    assert "version" in body
