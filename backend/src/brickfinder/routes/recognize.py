from __future__ import annotations

from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import Settings
from ..deps import (
    get_client_key,
    get_db_session,
    get_recognize_service,
    get_settings_dep,
    utcnow,
)
from ..errors import AppError
from ..schemas.common import ErrorCode
from ..schemas.recognize import RecognizeResponse
from ..services.recognize import RecognizeService

router = APIRouter(prefix="/v1")

_ALLOWED_PREFIX = "image/"


@router.post("/recognize", response_model=RecognizeResponse)
async def recognize(
    image: UploadFile = File(...),
    session: AsyncSession = Depends(get_db_session),
    service: RecognizeService = Depends(get_recognize_service),
    client_key: str = Depends(get_client_key),
    settings: Settings = Depends(get_settings_dep),
) -> RecognizeResponse:
    if not (image.content_type or "").startswith(_ALLOWED_PREFIX):
        raise AppError(
            code=ErrorCode.INVALID_INPUT,
            message="image content-type must be image/*",
            http_status=400,
        )

    data = await image.read()
    try:
        if len(data) == 0:
            raise AppError(
                code=ErrorCode.INVALID_INPUT,
                message="empty image",
                http_status=400,
            )
        if len(data) > settings.upload_max_bytes:
            raise AppError(
                code=ErrorCode.INVALID_INPUT,
                message=f"image exceeds {settings.upload_max_bytes} bytes",
                http_status=400,
            )

        response = await service.recognize(
            session,
            image_bytes=data,
            filename=image.filename or "upload.jpg",
            content_type=image.content_type or "image/jpeg",
            client_key=client_key,
            now=utcnow(),
        )
        await session.commit()
        return response
    finally:
        await image.close()
