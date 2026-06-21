from brickfinder.main import create_app


def test_health_unit():
    from fastapi.testclient import TestClient

    client = TestClient(create_app(), raise_server_exceptions=False)
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}
