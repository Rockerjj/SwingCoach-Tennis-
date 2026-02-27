import json
import logging
from uuid import uuid4
from datetime import datetime

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from typing import Optional
from supabase import Client

from app.models import SessionPosePayload, AnalysisResponse
from app.services.llm_coaching import LLMCoachingService
from app.services.progress_calculator import ProgressCalculator
from app.routes.deps import get_supabase, get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sessions", tags=["sessions"])


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_session(
    pose_data: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    supabase: Optional[Client] = Depends(get_supabase),
):
    pose_bytes = await pose_data.read()
    try:
        pose_dict = json.loads(pose_bytes)
        pose_payload = SessionPosePayload(**pose_dict)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid pose data: {e}")

    key_frame_images: list[bytes] = []
    session_id = pose_payload.session_id or str(uuid4())

    if supabase is not None:
        supabase.table("sessions").insert({
            "id": session_id,
            "user_id": user_id,
            "recorded_at": datetime.utcnow().isoformat(),
            "duration_seconds": pose_payload.duration_seconds,
            "status": "analyzing",
        }).execute()

    try:
        coaching = LLMCoachingService()
        result = await coaching.analyze_session(pose_payload, key_frame_images)

        if supabase is not None:
            for stroke in result.strokes_detected:
                stroke_row = {
                    "id": str(uuid4()),
                    "session_id": session_id,
                    "stroke_type": stroke.type,
                    "timestamp": stroke.timestamp,
                    "grade": stroke.grade,
                    "mechanics": stroke.mechanics.model_dump(),
                    "overlay_instructions": stroke.overlay_instructions.model_dump(),
                }
                if stroke.phase_breakdown:
                    stroke_row["phase_breakdown"] = stroke.phase_breakdown.model_dump()
                if stroke.analysis_categories:
                    stroke_row["analysis_categories"] = [c.model_dump() for c in stroke.analysis_categories]
                supabase.table("stroke_analyses").insert(stroke_row).execute()

            supabase.table("sessions").update({
                "status": "ready",
                "overall_grade": result.session_grade,
                "top_priority": result.top_priority,
                "tactical_notes": result.tactical_notes,
            }).eq("id", session_id).execute()

            calculator = ProgressCalculator(supabase)
            await calculator.update_progress(user_id, session_id)

        return result

    except Exception as e:
        logger.error(f"Analysis failed for session {session_id}: {e}")
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
