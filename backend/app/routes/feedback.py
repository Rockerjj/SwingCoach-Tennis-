import logging
from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from typing import Optional
from supabase import Client

from app.routes.deps import get_supabase

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackPayload(BaseModel):
    user_id: str = "anonymous"
    rating: int = Field(ge=1, le=5)
    comment: str = ""
    app_version: str = ""
    device_model: str = ""
    ios_version: str = ""
    timestamp: Optional[str] = None


@router.post("")
async def submit_feedback(
    payload: FeedbackPayload,
    supabase: Client = Depends(get_supabase),
):
    feedback_data = {
        "user_id": payload.user_id,
        "rating": payload.rating,
        "comment": payload.comment,
        "app_version": payload.app_version,
        "device_model": payload.device_model,
        "ios_version": payload.ios_version,
        "created_at": payload.timestamp or datetime.utcnow().isoformat(),
    }

    try:
        if supabase:
            supabase.table("user_feedback").insert(feedback_data).execute()
            logger.info("Feedback stored: rating=%d user=%s", payload.rating, payload.user_id)
        else:
            logger.warning("Supabase unavailable, logging feedback: %s", feedback_data)
    except Exception as exc:
        logger.error("Failed to store feedback: %s", exc)

    return {"status": "ok"}
