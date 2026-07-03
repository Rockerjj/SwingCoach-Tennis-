"""Labeler E: MediaPipe Pose joints + iOS heuristic logic.

Answers the central question: is the 62% iOS accuracy bug in the heuristic
LOGIC, or in the JOINT QUALITY (Apple Vision)? This labeler keeps the heuristic
identical to the Swift `StrokeDetector` and only swaps in MediaPipe joints.

If this gets to 80%+, MediaPipe alone fixes the problem and we don't need a
hosted model. If it's still ~60%, the heuristic itself is the issue.
"""
from __future__ import annotations

import logging
import math
import os
import tempfile
import time
from pathlib import Path

from . import Labeler, LabelerInput, LabelerResult, register

logger = logging.getLogger(__name__)


# All 33 MediaPipe Pose keypoints — the full BlazePose schema.
# The hosted-model labelers see all of these; the legacy iOS heuristic only
# touches the 13-keypoint subset below.
MP_LANDMARKS = {
    0: "nose",
    1: "left_eye_inner",
    2: "left_eye",
    3: "left_eye_outer",
    4: "right_eye_inner",
    5: "right_eye",
    6: "right_eye_outer",
    7: "left_ear",
    8: "right_ear",
    9: "mouth_left",
    10: "mouth_right",
    11: "left_shoulder",
    12: "right_shoulder",
    13: "left_elbow",
    14: "right_elbow",
    15: "left_wrist",
    16: "right_wrist",
    17: "left_pinky",
    18: "right_pinky",
    19: "left_index",
    20: "right_index",
    21: "left_thumb",
    22: "right_thumb",
    23: "left_hip",
    24: "right_hip",
    25: "left_knee",
    26: "right_knee",
    27: "left_ankle",
    28: "right_ankle",
    29: "left_heel",
    30: "right_heel",
    31: "left_foot_index",
    32: "right_foot_index",
}


# --- iOS heuristic constants (kept identical to StrokeDetector.swift) ---
MIN_CONFIDENCE = 0.3
MIN_TIME_BETWEEN_STROKES = 2.0
VELOCITY_THRESHOLD = 0.025


# Path to the same model bundle the iOS app uses. Resolves to
# <repo_root>/TennisIQ/Resources/pose_landmarker_full.task by walking up from
# this file (.../backend/app/services/labelers/mediapipe_heuristic.py).
_REPO_ROOT = Path(__file__).resolve().parents[4]
_DEFAULT_MODEL_PATH = os.environ.get(
    "MEDIAPIPE_POSE_MODEL",
    str(_REPO_ROOT / "TennisIQ" / "Resources" / "pose_landmarker_full.task"),
)


def _extract_mediapipe_joints(clip_path: str, model_path: str = _DEFAULT_MODEL_PATH) -> list[dict]:
    """Run MediaPipe Pose Landmarker on a video clip via the Tasks API.

    Returns one dict per frame:
        {"timestamp": float (seconds), "joints": {name: {"x", "y", "confidence"}}}
    Coordinates are normalized 0-1 of frame dimensions.
    """
    import cv2
    import mediapipe as mp
    from mediapipe.tasks import python as mp_python
    from mediapipe.tasks.python import vision

    if not os.path.isfile(model_path):
        raise RuntimeError(f"pose_landmarker model not found at {model_path}")

    cap = cv2.VideoCapture(clip_path)
    if not cap.isOpened():
        raise RuntimeError(f"cannot open clip: {clip_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frames_out: list[dict] = []

    base_options = mp_python.BaseOptions(model_asset_path=model_path)
    options = vision.PoseLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    with vision.PoseLandmarker.create_from_options(options) as landmarker:
        frame_idx = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
            timestamp_ms = int((frame_idx / fps) * 1000)
            result = landmarker.detect_for_video(mp_image, timestamp_ms)

            timestamp_s = frame_idx / fps
            joints: dict[str, dict] = {}
            if result.pose_landmarks:
                landmarks = result.pose_landmarks[0]
                for mp_idx, name in MP_LANDMARKS.items():
                    lm = landmarks[mp_idx]
                    # Flip y-axis to match Apple Vision convention (y=1 top, y=0 bottom).
                    # The Swift heuristic in StrokeDetector.swift assumes Vision coords —
                    # without this flip, the volley height-zone check fires on every stroke.
                    joints[name] = {
                        "x": lm.x,
                        "y": 1.0 - lm.y,
                        "confidence": lm.visibility,
                    }
            frames_out.append({"timestamp": timestamp_s, "joints": joints})
            frame_idx += 1
    cap.release()
    return frames_out


# --- Heuristic port (mirrors StrokeDetector.swift) ---
def _wrist_velocities(frames: list[dict], wrist_name: str) -> list[float]:
    """Smoothed dominant-wrist speed per frame (same shape as Swift)."""
    velocities: list[float] = [0.0]
    for i in range(1, len(frames)):
        c = frames[i]["joints"].get(wrist_name)
        p = frames[i - 1]["joints"].get(wrist_name)
        if (c is None or p is None or
                c["confidence"] < MIN_CONFIDENCE or p["confidence"] < MIN_CONFIDENCE):
            velocities.append(0.0)
            continue
        dt = frames[i]["timestamp"] - frames[i - 1]["timestamp"]
        if dt <= 0:
            velocities.append(0.0)
            continue
        dist = math.hypot(c["x"] - p["x"], c["y"] - p["y"])
        velocities.append(dist / dt)
    # 3-frame moving average
    out = []
    for i in range(len(velocities)):
        lo = max(0, i - 1)
        hi = min(len(velocities) - 1, i + 1)
        s = velocities[lo:hi + 1]
        out.append(sum(s) / len(s))
    return out


def _find_contact_peaks(velocities: list[float], frames: list[dict]) -> list[int]:
    if len(velocities) < 5:
        return []
    avg_v = sum(velocities) / len(velocities)
    dyn_thresh = max(VELOCITY_THRESHOLD, avg_v * 2.0)
    peaks: list[int] = []
    last_peak_t = -100.0
    for i in range(2, len(velocities) - 2):
        is_peak = (velocities[i] > velocities[i - 1] and
                   velocities[i] > velocities[i - 2] and
                   velocities[i] >= velocities[i + 1] and
                   velocities[i] > dyn_thresh)
        if is_peak and (frames[i]["timestamp"] - last_peak_t) > MIN_TIME_BETWEEN_STROKES:
            peaks.append(i)
            last_peak_t = frames[i]["timestamp"]
    return peaks


def _scan_backward(start: int, velocities: list[float], cond) -> int:
    i = start
    while i > 0:
        i -= 1
        if cond(velocities[i]):
            return i
    return max(0, start - 3)


def _scan_forward(start: int, velocities: list[float], cond, n: int) -> int:
    i = start
    while i < n - 1:
        i += 1
        if cond(velocities[i]):
            return i
    return min(n - 1, start + 3)


def _shoulder_rotation(frame: dict) -> float | None:
    j = frame["joints"]
    ls = j.get("left_shoulder")
    rs = j.get("right_shoulder")
    if ls is None or rs is None or ls["confidence"] < MIN_CONFIDENCE or rs["confidence"] < MIN_CONFIDENCE:
        return None
    dx = rs["x"] - ls["x"]
    dy = rs["y"] - ls["y"]
    return math.degrees(math.atan2(abs(dy), abs(dx)))


def _scan_back_for_shoulder_change(start: int, frames: list[dict]) -> int:
    sr_start = _shoulder_rotation(frames[start])
    i = start
    while i > 0:
        i -= 1
        sr = _shoulder_rotation(frames[i])
        if sr_start is not None and sr is not None and abs(sr_start - sr) > 10:
            return i
    return max(0, start - 2)


def _infer_stroke_type(idx: int, frames: list[dict], handedness: str = "right") -> str:
    f = frames[idx]
    j = f["joints"]
    wrist_name = "right_wrist" if handedness == "right" else "left_wrist"
    wrist = j.get(wrist_name)
    nose = j.get("nose")
    if (wrist is None or nose is None or
            wrist["confidence"] < MIN_CONFIDENCE or nose["confidence"] < MIN_CONFIDENCE):
        return "forehand"

    # Serve: wrist well above nose at contact (note: y increases downward in image space,
    # so "above nose" means smaller y. Swift uses inverted normalized coords where
    # higher y == higher in frame. We mirror Swift exactly.)
    if wrist["y"] > nose["y"] + 0.15:
        return "serve"

    # Volley: compact swing + wrist near chest, see iOS isVolleyLikely
    if _is_volley_likely(idx, frames, j, wrist, wrist_name):
        return "volley"

    ls = j.get("left_shoulder", {"x": 0.5})
    rs = j.get("right_shoulder", {"x": 0.5})
    mid_x = (ls["x"] + rs["x"]) / 2
    if handedness == "right":
        return "forehand" if wrist["x"] > mid_x else "backhand"
    return "forehand" if wrist["x"] < mid_x else "backhand"


def _is_volley_likely(idx: int, frames: list[dict], j: dict, wrist: dict, wrist_name: str) -> bool:
    ls = j.get("left_shoulder", {"y": 0.5})
    rs = j.get("right_shoulder", {"y": 0.5})
    lh = j.get("left_hip", {"y": 0.3})
    rh = j.get("right_hip", {"y": 0.3})
    shoulder_y = (ls["y"] + rs["y"]) / 2
    hip_y = (lh["y"] + rh["y"]) / 2
    if not (hip_y - 0.05 <= wrist["y"] <= shoulder_y + 0.10):
        return False
    contact_t = frames[idx]["timestamp"]
    lookback = [f for f in frames if contact_t - 0.5 <= f["timestamp"] <= contact_t]
    if len(lookback) < 3:
        return False
    total = 0.0
    for i in range(1, len(lookback)):
        c = lookback[i]["joints"].get(wrist_name)
        p = lookback[i - 1]["joints"].get(wrist_name)
        if c and p and c["confidence"] >= MIN_CONFIDENCE and p["confidence"] >= MIN_CONFIDENCE:
            total += math.hypot(c["x"] - p["x"], c["y"] - p["y"])
    # Compact swing threshold mirroring Swift
    return total < 0.30


def _detect_strokes(frames: list[dict], handedness: str = "right") -> list[dict]:
    """Returns a list of {type, contact_clip_t, phases: {name: clip_t}}."""
    if len(frames) < 10:
        return []
    frames = sorted(frames, key=lambda f: f["timestamp"])
    wrist_name = "right_wrist" if handedness == "right" else "left_wrist"
    velocities = _wrist_velocities(frames, wrist_name)
    contact_indices = _find_contact_peaks(velocities, frames)

    strokes = []
    n = len(frames)
    for c_idx in contact_indices:
        contact_v = velocities[c_idx]
        forward_swing_idx = _scan_backward(c_idx, velocities, lambda v: v < contact_v * 0.5)
        backswing_idx = _scan_backward(forward_swing_idx, velocities, lambda v: v < 0.01)
        unit_turn_idx = _scan_back_for_shoulder_change(backswing_idx, frames)
        ready_idx = _scan_backward(unit_turn_idx, velocities, lambda v: v < 0.005)
        follow_idx = _scan_forward(c_idx, velocities, lambda v: v < contact_v * 0.3, n)
        recovery_idx = _scan_forward(follow_idx, velocities, lambda v: v < 0.01, n)

        phases_t = {
            "ready_position": frames[ready_idx]["timestamp"],
            "unit_turn": frames[unit_turn_idx]["timestamp"],
            "backswing": frames[backswing_idx]["timestamp"],
            "forward_swing": frames[forward_swing_idx]["timestamp"],
            "contact_point": frames[c_idx]["timestamp"],
            "follow_through": frames[follow_idx]["timestamp"],
            "recovery": frames[recovery_idx]["timestamp"],
        }

        # If ordering is invalid, fall back to fixed offsets around contact
        ordered_keys = [
            "ready_position", "unit_turn", "backswing", "forward_swing",
            "contact_point", "follow_through", "recovery",
        ]
        ordered_vals = [phases_t[k] for k in ordered_keys]
        if not all(ordered_vals[i] < ordered_vals[i + 1] for i in range(len(ordered_vals) - 1)):
            ct = frames[c_idx]["timestamp"]
            phases_t = {
                "ready_position": max(0, ct - 1.5),
                "unit_turn": max(0, ct - 1.2),
                "backswing": max(0, ct - 0.8),
                "forward_swing": max(0, ct - 0.4),
                "contact_point": ct,
                "follow_through": ct + 0.3,
                "recovery": ct + 0.8,
            }

        strokes.append({
            "type": _infer_stroke_type(c_idx, frames, handedness),
            "contact_clip_t": frames[c_idx]["timestamp"],
            "phases_clip_t": phases_t,
        })
    return strokes


class MediaPipeHeuristicLabeler:
    name = "mediapipe_heuristic"

    async def label(self, stroke: LabelerInput) -> LabelerResult:
        started = time.perf_counter()
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(stroke.clip_bytes)
            tmp = f.name
        try:
            try:
                frames = _extract_mediapipe_joints(tmp)
            except Exception as e:
                return LabelerResult(
                    stroke_type="unknown", phases={},
                    latency_ms=int((time.perf_counter() - started) * 1000),
                    error=f"mediapipe extraction failed: {type(e).__name__}: {e}",
                )

            strokes = _detect_strokes(frames, handedness="right")
            latency_ms = int((time.perf_counter() - started) * 1000)

            if not strokes:
                return LabelerResult(
                    stroke_type="unknown", phases={},
                    latency_ms=latency_ms,
                    error="no contact peak found in clip",
                )

            # Pick the stroke whose contact is closest to the middle of the clip
            clip_dur = frames[-1]["timestamp"] if frames else 3.0
            mid = clip_dur / 2
            best = min(strokes, key=lambda s: abs(s["contact_clip_t"] - mid))

            # Convert clip-relative -> session-absolute
            clip_start_abs = stroke.clip_timestamp
            phases_abs = {k: v + clip_start_abs for k, v in best["phases_clip_t"].items()}

            return LabelerResult(
                stroke_type=best["type"],
                phases=phases_abs,
                latency_ms=latency_ms,
                input_tokens=0,
                output_tokens=0,
                cost_cents_estimate=0.0,
                raw_response=f"mediapipe frames={len(frames)} strokes_in_clip={len(strokes)}",
            )
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass


try:
    register(MediaPipeHeuristicLabeler())
except Exception as e:
    logger.warning(f"MediaPipe heuristic labeler unavailable: {e}")
