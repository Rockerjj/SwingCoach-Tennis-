"""Server-side stroke + phase relabeler.

The iOS heuristic in `StrokeDetector.swift` produces 62% stroke-type accuracy
(see Phase Detection Labeler Bake-off memo). Before the coaching LLM runs, we
overwrite those iOS labels with output from the MediaPipe + Gemini labeler that
hit 100% on every confident call in the v5 bake-off.

The flow:
  1. iOS sends pose_data with its (possibly wrong) labels + per-stroke video clips.
  2. This module spawns one mediapipe_gemini call per stroke clip in parallel.
  3. For each stroke, replaces `type` and per-phase `timestamp` with the labeler output.
  4. Falls back to mediapipe_sonnet for any stroke where the primary returned `unknown`
     or errored. (Sonnet is slower but had 0 type errors on the bake-off.)
  5. Returns a new SessionPosePayload — the coaching LLM never sees iOS labels.

Behavior is gated on `settings.relabel_strokes` so we can A/B in production.
"""
from __future__ import annotations

import asyncio
import logging
import os
import subprocess
import tempfile
import time

from app.config import get_settings
from app.models import (
    DetectedStrokeData,
    DetectedPhaseData,
    SessionPosePayload,
)
from app.services.labelers import LabelerInput, get as get_labeler

logger = logging.getLogger(__name__)


PHASE_NAMES = (
    "ready_position",
    "unit_turn",
    "backswing",
    "forward_swing",
    "contact_point",
    "follow_through",
    "recovery",
)
MIN_RELABEL_CONFIDENCE = 0.75


def _clip_duration_seconds(clip_bytes: bytes) -> float:
    try:
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(clip_bytes)
            tmp = f.name
        try:
            out = subprocess.check_output(
                [
                    "ffprobe", "-v", "error",
                    "-show_entries", "format=duration",
                    "-of", "default=noprint_wrappers=1:nokey=1",
                    tmp,
                ],
                stderr=subprocess.DEVNULL,
            )
            return max(float(out.decode().strip()), 0.1)
        finally:
            os.unlink(tmp)
    except Exception:
        return 3.0


def _is_relabel_usable(
    result,
    clip_start: float,
    clip_duration: float,
    min_confidence: float = MIN_RELABEL_CONFIDENCE,
) -> bool:
    if result.error or result.stroke_type == "unknown":
        return False
    if result.confidence is None or result.confidence < min_confidence:
        return False
    if any(result.phases.get(name) is None for name in PHASE_NAMES):
        return False
    if not result.ordering_valid():
        return False

    contact = result.phases.get("contact_point")
    clip_end = clip_start + clip_duration
    return contact is not None and clip_start <= contact <= clip_end


def _match_clip_for_stroke(
    stroke: DetectedStrokeData,
    clips: list[tuple[float, bytes]],
) -> tuple[float, bytes] | None:
    """Pick the clip whose recorded timestamp is closest to this stroke's contact."""
    if not clips:
        return None
    contact_t = stroke.contact_timestamp
    if contact_t == 0:
        # Fall back to whichever phase has a timestamp
        for ph_name in PHASE_NAMES:
            ph = stroke.phases.get(ph_name)
            if ph and ph.timestamp:
                contact_t = ph.timestamp
                break
    return min(clips, key=lambda c: abs(c[0] - contact_t))


async def _label_one(
    stroke_idx: int,
    stroke: DetectedStrokeData,
    clip: tuple[float, bytes],
    primary: str,
    fallback: str,
) -> tuple[int, dict | None]:
    """Run the primary labeler; on error or `unknown`, try the fallback.
    Returns (idx, {stroke_type, phases}) or (idx, None) on hard failure.
    """
    contact_t = stroke.contact_timestamp or clip[0]
    clip_duration = _clip_duration_seconds(clip[1])
    clip_start = max(0.0, contact_t - (clip_duration / 2.0))
    label_input = LabelerInput(
        session_id="relabel",
        stroke_idx=stroke_idx,
        clip_bytes=clip[1],
        clip_timestamp=clip_start,
        ios_stroke_type=stroke.type,
        ios_phases={
            name: ph.timestamp for name, ph in stroke.phases.items() if ph.timestamp
        },
    )
    for labeler_name in (primary, fallback):
        try:
            labeler = get_labeler(labeler_name)
            result = await labeler.label(label_input)
            if result.error:
                logger.warning(
                    f"relabel: stroke {stroke_idx} via {labeler_name} errored: {result.error}"
                )
                continue
            if result.stroke_type == "unknown":
                logger.info(
                    f"relabel: stroke {stroke_idx} via {labeler_name} returned unknown, trying fallback"
                )
                continue
            if not _is_relabel_usable(result, clip_start, clip_duration):
                logger.info(
                    f"relabel: stroke {stroke_idx} via {labeler_name} failed validation "
                    f"(confidence={result.confidence}, phases={len(result.phases)})"
                )
                continue
            return stroke_idx, {
                "stroke_type": result.stroke_type,
                "phases": result.phases,
                "labeler": labeler_name,
                "confidence": result.confidence,
            }
        except Exception as e:
            logger.warning(f"relabel: stroke {stroke_idx} via {labeler_name} crashed: {e}")
            continue
    return stroke_idx, None


def _replace_stroke(stroke: DetectedStrokeData, new: dict) -> DetectedStrokeData:
    """Build a new DetectedStrokeData with corrected type + phase timestamps,
    preserving the original measured angles (those came from real joint data)."""
    new_phases: dict[str, DetectedPhaseData] = {}
    for ph_name in PHASE_NAMES:
        new_ts = new["phases"].get(ph_name)
        old = stroke.phases.get(ph_name)
        if new_ts is None and old is None:
            continue
        new_phases[ph_name] = DetectedPhaseData(
            timestamp=new_ts if new_ts is not None else (old.timestamp if old else 0.0),
            angles=old.angles if old else {},
        )
    contact_ts = new["phases"].get("contact_point", stroke.contact_timestamp)
    return DetectedStrokeData(
        type=new["stroke_type"],
        contactTimestamp=contact_ts,
        phases=new_phases,
    )


async def relabel_session(
    payload: SessionPosePayload,
    video_clips: list[tuple[float, bytes]],
) -> SessionPosePayload:
    """Replace iOS stroke labels with mediapipe_gemini output (sonnet fallback).

    Returns a new SessionPosePayload. Original is unchanged. If relabeling
    fails for any individual stroke, that stroke keeps its iOS-provided labels.
    """
    settings = get_settings()
    if not getattr(settings, "relabel_strokes", False):
        return payload
    if not payload.detected_strokes or not video_clips:
        return payload

    primary = "mediapipe_gemini"
    fallback = "mediapipe_sonnet"

    started = time.perf_counter()
    tasks = []
    for i, stroke in enumerate(payload.detected_strokes):
        clip = _match_clip_for_stroke(stroke, video_clips)
        if clip is None:
            continue
        tasks.append(_label_one(i, stroke, clip, primary, fallback))

    results = await asyncio.gather(*tasks, return_exceptions=False)
    elapsed_ms = int((time.perf_counter() - started) * 1000)

    relabeled: dict[int, dict] = {}
    for idx, new in results:
        if new is not None:
            relabeled[idx] = new

    overwritten = 0
    new_strokes: list[DetectedStrokeData] = []
    for i, stroke in enumerate(payload.detected_strokes):
        if i in relabeled:
            new_strokes.append(_replace_stroke(stroke, relabeled[i]))
            overwritten += 1
        else:
            new_strokes.append(stroke)

    logger.info(
        f"relabel: overwrote {overwritten}/{len(payload.detected_strokes)} strokes "
        f"in {elapsed_ms}ms (primary={primary}, fallback={fallback})"
    )

    return payload.model_copy(update={"detected_strokes": new_strokes})
