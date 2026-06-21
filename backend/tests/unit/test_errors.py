from fastapi import FastAPI
from fastapi.testclient import TestClient

from brickfinder.errors import AppError, ErrorCode, register_exception_handlers
from brickfinder.schemas.common import ErrorResponse


def _build_app() -> FastAPI:
    app = FastAPI()

    @app.get("/boom")
    def boom() -> None:
        raise AppError(
            code=ErrorCode.UPSTREAM_TIMEOUT,
            message="Brickognize timed out",
            http_status=504,
            retry_after_seconds=5,
        )

    @app.get("/oops")
    def oops() -> None:
        raise RuntimeError("internal failure")

    register_exception_handlers(app)
    return app


def test_app_error_serialized():
    client = TestClient(_build_app(), raise_server_exceptions=False)
    r = client.get("/boom")
    assert r.status_code == 504
    body = r.json()
    parsed = ErrorResponse.model_validate(body)
    assert parsed.code == ErrorCode.UPSTREAM_TIMEOUT
    assert parsed.message == "Brickognize timed out"
    assert parsed.retry_after_seconds == 5


def test_unhandled_exception_becomes_internal():
    client = TestClient(_build_app(), raise_server_exceptions=False)
    r = client.get("/oops")
    assert r.status_code == 500
    body = r.json()
    parsed = ErrorResponse.model_validate(body)
    assert parsed.code == ErrorCode.INTERNAL
    # Must NOT leak the original message
    assert "internal failure" not in parsed.message
