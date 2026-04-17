import json
import logging
import time
from pathlib import Path
from uuid import uuid4
from datetime import datetime

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException, Request
from typing import Optional
from supabase import Client

from app.models import SessionPosePayload, AnalysisResponse
from app.services.llm_coaching import LLMCoachingService
from app.services.gemini_coaching import GeminiCoachingService
from app.services.claude_coaching import ClaudeCoachingService
from app.services.progress_calculator import ProgressCalculator
from app.config import get_settings
from app.routes.deps import get_supabase, get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/sessions", tags=["sessions"])


def _capture_payload(
    capture_dir: str,
    session_id: str,
    user_id: str,
    pose_bytes: bytes,
    key_frame_images: list[bytes],
    video_clips: list[tuple[float, bytes]],
) -> None:
    """Write the incoming analyze payload to disk for the eval harness.

    Layout:
      <capture_dir>/<session_id>/
        metadata.json
        pose_data.json
        key_frames/key_frame_000.jpg ...
        stroke_clips/stroke_clip_000_<ts>.mp4 ...
    """
    try:
        base = Path(capture_dir) / session_id
        (base / "key_frames").mkdir(parents=True, exist_ok=True)
        (base / "stroke_clips").mkdir(parents=True, exist_ok=True)

        (base / "pose_data.json").write_bytes(pose_bytes)

        for idx, img in enumerate(key_frame_images):
            (base / "key_frames" / f"key_frame_{idx:03d}.jpg").write_bytes(img)

        for idx, (ts, clip) in enumerate(video_clips):
            (base / "stroke_clips" / f"stroke_clip_{idx:03d}_{ts:.2f}.mp4").write_bytes(clip)

        meta = {
            "session_id": session_id,
            "user_id": user_id,
            "received_at": datetime.utcnow().isoformat() + "Z",
            "key_frame_count": len(key_frame_images),
            "stroke_clip_count": len(video_clips),
            "stroke_clip_timestamps": [ts for ts, _ in video_clips],
        }
        (base / "metadata.json").write_text(json.dumps(meta, indent=2))
        logger.info(
            f"Captured payload for session {session_id} to {base} "
            f"({len(key_frame_images)} frames, {len(video_clips)} clips)"
        )
    except Exception as e:
        # Never let capture errors break the actual analyze request.
        logger.warning(f"Failed to capture payload for session {session_id}: {e}")


@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_session(
    request: Request,
    user_id: str = Depends(get_current_user_id),
    supabase: Optional[Client] = Depends(get_supabase),
):
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
                logger.warning(f"Failed to read {key}: {e}")

    # Read video clip files from multipart (stroke_clip_0, stroke_clip_1, ...)
    video_clips: list[tuple[float, bytes]] = []
    for key in sorted(form.keys()):
        if key.startswith("stroke_clip_"):
            try:
                clip_file = form[key]
                clip_bytes = await clip_file.read()
                # Extract timestamp from filename (e.g., "clip_0_8.20.mp4")
                filename = getattr(clip_file, "filename", "") or ""
                ts = 0.0
                parts = filename.replace(".mp4", "").split("_")
                if len(parts) >= 3:
                    try:
                        ts = float(parts[2])
                    except ValueError:
                        pass
                if clip_bytes:
                    video_clips.append((ts, clip_bytes))
            except Exception as e:
                logger.warning(f"Failed to read {key}: {e}")

    logger.info(f"Received {len(key_frame_images)} key frame images and {len(video_clips)} video clips for analysis")
    session_id = pose_payload.session_id or str(uuid4())

    settings = get_settings()

    if settings.debug_capture_payloads:
        _capture_payload(
            settings.payload_capture_dir,
            session_id,
            user_id,
            pose_bytes,
            key_frame_images,
            video_clips,
        )

    if supabase is not None:
        supabase.table("sessions").upsert({
            "id": session_id,
            "user_id": user_id,
            "recorded_at": datetime.utcnow().isoformat(),
            "duration_seconds": pose_payload.duration_seconds,
            "status": "analyzing",
        }).execute()

    started_at = time.perf_counter()
    provider_used = "unknown"
    model_used = "unknown"
    coaching = None

    try:
        provider = settings.coaching_provider

        # "auto" preserves the legacy behavior: prefer Gemini if configured,
        # otherwise fall back to OpenAI. Explicit values override.
        if provider == "auto":
            provider = "gemini" if (settings.use_gemini and settings.gemini_api_key) else "openai"

        if provider == "gemini":
            coaching = GeminiCoachingService()
            result = await coaching.analyze_session(
                pose_payload, key_frame_images, video_clips or None
            )
            provider_used, model_used = "gemini", settings.gemini_model
            logger.info(f"Analysis completed via Gemini ({model_used})")
        elif provider == "claude_opus":
            coaching = ClaudeCoachingService(model=settings.anthropic_opus_model)
            result = await coaching.analyze_session(pose_payload, key_frame_images)
            provider_used, model_used = "claude_opus", settings.anthropic_opus_model
            logger.info(f"Analysis completed via Claude Opus ({model_used})")
        elif provider == "claude_sonnet":
            coaching = ClaudeCoachingService(model=settings.anthropic_sonnet_model)
            result = await coaching.analyze_session(pose_payload, key_frame_images)
            provider_used, model_used = "claude_sonnet", settings.anthropic_sonnet_model
            logger.info(f"Analysis completed via Claude Sonnet ({model_used})")
        elif provider == "openai":
            coaching = LLMCoachingService()
            result = await coaching.analyze_session(pose_payload, key_frame_images)
            provider_used, model_used = "openai", settings.openai_model
            logger.info(f"Analysis completed via OpenAI ({model_used})")
        else:
            raise HTTPException(status_code=500, detail=f"Unknown coaching_provider: {provider}")

        latency_ms = int((time.perf_counter() - started_at) * 1000)

        # Best-effort cost tracking — non-fatal if the table doesn't exist yet.
        if supabase is not None:
            usage = getattr(coaching, "last_usage", None) or {}
            in_tok = usage.get("input_tokens")
            out_tok = usage.get("output_tokens")
            cost_cents = None
            if in_tok is not None and out_tok is not None:
                try:
                    from scripts.pricing import estimate_cost_cents
                    cost_cents = estimate_cost_cents(model_used, in_tok, out_tok)
                except Exception:
                    cost_cents = None
            try:
                supabase.table("analysis_runs").insert({
                    "id": str(uuid4()),
                    "session_id": session_id,
                    "user_id": user_id,
                    "provider": provider_used,
                    "model": model_used,
                    "input_tokens": in_tok,
                    "output_tokens": out_tok,
                    "cost_cents": cost_cents,
                    "latency_ms": latency_ms,
                    "success": True,
                }).execute()
            except Exception as e:
                logger.debug(f"analysis_runs insert skipped: {e}")

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
        latency_ms = int((time.perf_counter() - started_at) * 1000)
        logger.error(f"Analysis failed for session {session_id}: {e}")
        if supabase is not None:
            supabase.table("sessions").update({
                "status": "failed",
            }).eq("id", session_id).execute()
            try:
                supabase.table("analysis_runs").insert({
                    "id": str(uuid4()),
                    "session_id": session_id,
                    "user_id": user_id,
                    "provider": provider_used,
                    "model": model_used,
                    "latency_ms": latency_ms,
                    "success": False,
                    "error": str(e)[:500],
                }).execute()
            except Exception as inner:
                logger.debug(f"analysis_runs failure insert skipped: {inner}")
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
