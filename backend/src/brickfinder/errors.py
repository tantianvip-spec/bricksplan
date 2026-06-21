from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .logging import get_logger
from .schemas.common import ErrorCode, ErrorResponse

log = get_logger(__name__)


class AppError(Exception):
    def __init__(
        self,
        code: ErrorCode,
        message: str,
        *,
        http_status: int,
        retry_after_seconds: int | None = None,
    ) -> None:
        self.code = code
        self.message = message
        self.http_status = http_status
        self.retry_after_seconds = retry_after_seconds
        super().__init__(message)


def _json(body: ErrorResponse, status: int) -> JSONResponse:
    return JSONResponse(status_code=status, content=body.model_dump(mode="json"))


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def _handle_app_error(_: Request, exc: AppError) -> JSONResponse:
        return _json(
            ErrorResponse(
                code=exc.code,
                message=exc.message,
                retry_after_seconds=exc.retry_after_seconds,
            ),
            exc.http_status,
        )

    @app.exception_handler(RequestValidationError)
    async def _handle_validation(_: Request, exc: RequestValidationError) -> JSONResponse:
        return _json(
            ErrorResponse(code=ErrorCode.INVALID_INPUT, message="Invalid request"),
            400,
        )

    @app.exception_handler(Exception)
    async def _handle_unexpected(_: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled_exception", error=repr(exc))
        return _json(
            ErrorResponse(code=ErrorCode.INTERNAL, message="Internal error"),
            500,
        )
