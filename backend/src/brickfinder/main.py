from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from .config import get_settings
from .errors import register_exception_handlers
from .logging import configure_logging
from .routes import health, parts, recognize


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging(get_settings())
    yield


def create_app() -> FastAPI:
    app = FastAPI(title="brickfinder", lifespan=lifespan)
    register_exception_handlers(app)
    app.include_router(health.router)
    app.include_router(recognize.router)
    app.include_router(parts.router)
    return app


app = create_app()
