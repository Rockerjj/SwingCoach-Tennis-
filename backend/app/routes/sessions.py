import json
import logging
from uuid import uuid4
from datetime import datetime

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Request
from typing import Optional
from supabase import Client

from app.models import SessionPosePayload, AnalysisResponse
from app.services.llm_coaching import LLMCoachingService
from app.services.progress_calculator import ProgressCalculator
from app.routes.deps import get_supabase, get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sessions", tags=["sessions"])


def _req_log(request_id: str, msg: str) -> None:
    logger.info(f"[{request_id}] {msg}")


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_session(
    request: Request,
    user_id: str = Depends(get_current_user_id),
    supabase: Optional[Client] = Depends(get_supabase),
):
    request_id = str(uuid4())[:8]
    _req_log(request_id, f"analyze_session start — user={user_id[:8] if len(user_id) > 8 else user_id}")

    # Parse multipart form: pose_data + key_frame_0, key_frame_1, ...
    form = await request.form()

    pose_file = form.get("pose_data")
    if pose_file is None:
        raise HTTPException(status_code=400, detail="Missing pose_data")

    pose_bytes = await pose_file.read()
    try:
        pose_dict = json.loads(pose_bytes)
        pose_payload = SessionPosePayload(**pose_dict)
    except Exception as e:
        _req_log(request_id, f"Invalid pose data: {e}")
        raise HTTPException(status_code=400, detail=f"Invalid pose data: {e}")

    # Read all key frame images from multipart (key_frame_0, key_frame_1, ...)
    key_frame_images: list[bytes] = []
    for key in sorted(form.keys()):
        if key.startswith("key_frame_"):
            try:
                img_bytes = await form[key].read()
                if img_bytes:
                    key_frame_images.append(img_bytes)
            except Exception as e:
                _req_log(request_id, f"Failed to read {key}: {e}")

    _req_log(request_id, f"Received {len(key_frame_images)} key frames, {len(pose_payload.detected_strokes)} strokes")
    session_id = pose_payload.session_id or str(uuid4())

    if supabase is not None:
        supabase.table("sessions").upsert({
            "id": session_id,
            "user_id": user_id,
            "recorded_at": datetime.utcnow().isoformat(),
            "duration_seconds": pose_payload.duration_seconds,
            "status": "analyzing",
        }).execute()

    try:
        coaching = LLMCoachingService()
        result = await coaching.analyze_session(pose_payload, key_frame_images, request_id=request_id)

        if supabase is not None:
            for stroke in result.strokes_detected:
                stroke_row = {
                    "id": str(uuid4()),
                    "session_id": session_id,
                    "stroke_type": stroke.type,
                    "timestamp": stroke.timestamp,
                    "grade": stroke.grade,
                    "mechanics": stroke.mechanics.model_dump() if stroke.mechanics else {},
                    "overlay_instructions": stroke.overlay_instructions.model_dump() if stroke.overlay_instructions else {},
                }
                try:
                    supabase.table("stroke_analyses").insert(stroke_row).execute()
                except Exception as e:
                    logger.warning(f"Failed to insert stroke analysis: {e}")

            supabase.table("sessions").update({
                "status": "ready",
                "overall_grade": result.session_grade,
                "top_priority": result.top_priority,
                "tactical_notes": result.tactical_notes,
            }).eq("id", session_id).execute()

            calculator = ProgressCalculator(supabase)
            calculator.update_progress(user_id, session_id)

        return result

    except Exception as e:
        _req_log(request_id, f"Analysis failed for session {session_id}: {e}")
        if supabase is not None:
            supabase.table("sessions").update({
                "status": "failed",
            }).eq("id", session_id).execute()
        raise HTTPException(status_code=500, detail=f"Analysis failed: {e}")


@router.get("")
def list_sessions(
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    result = (
        supabase.table("sessions")
        .select("id, recorded_at, duration_seconds, overall_grade, status")
        .eq("user_id", user_id)
        .order("recorded_at", desc=True)
        .execute()
    )
    return result.data or []


@router.get("/{session_id}")
def get_session(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    session = (
        supabase.table("sessions")
        .select("*")
        .eq("id", session_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    if not session.data:
        raise HTTPException(status_code=404, detail="Session not found")

    strokes = (
        supabase.table("stroke_analyses")
        .select("*")
        .eq("session_id", session_id)
        .order("timestamp")
        .execute()
    )

    return {
        **session.data,
        "strokes": strokes.data or [],
    }
