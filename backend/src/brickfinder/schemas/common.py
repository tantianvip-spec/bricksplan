from enum import StrEnum

from pydantic import BaseModel


class ErrorCode(StrEnum):
    INVALID_INPUT = "INVALID_INPUT"
    UPSTREAM_TIMEOUT = "UPSTREAM_TIMEOUT"
    UPSTREAM_ERROR = "UPSTREAM_ERROR"
    RATE_LIMITED = "RATE_LIMITED"
    INTERNAL = "INTERNAL"


class ErrorResponse(BaseModel):
    code: ErrorCode
    message: str
    retry_after_seconds: int | None = None
