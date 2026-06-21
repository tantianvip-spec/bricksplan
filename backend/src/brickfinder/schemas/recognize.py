from __future__ import annotations

from pydantic import BaseModel, Field


class PartItem(BaseModel):
    part_num: str
    color_id: int = Field(description="Rebrickable color id; -1 if unknown")
    quantity: int = Field(ge=1)
    confidence: float | None = Field(default=None, ge=0.0, le=1.0)


class RecognizeResponse(BaseModel):
    parts: list[PartItem]
    cache_hit: bool
    low_confidence_count: int
