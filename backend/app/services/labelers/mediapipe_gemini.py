"""Labeler G: MediaPipe joint trajectories + Gemini 2.5 Pro vision.

Same hybrid as `mediapipe_claude.py` but uses Gemini's native video understanding
rather than Claude's frame-batch + tool-use. Hypothesis: Gemini's video reasoning
+ explicit MediaPipe trajectories matches Claude's accuracy at ~1/45 the cost.
"""
from __future__ import annotations

import json
import logging
import os
import re
import tempfile
import time

from app.config import get_settings
from app.prompts.phase_detector_gemini import PHASE_DETECTOR_SYSTEM

from . import Labeler, LabelerInput, LabelerResult, register
from .mediapipe_heuristic import _extract_mediapipe_joints

logger = logging.getLogger(__name__)


TRAJECTORY_SAMPLE_COUNT = 30


def _subsample_trajectory(joints_per_frame: list[dict], target: int) -> list[dict]:
    if len(joints_per_frame) <= target:
        rows = joints_per_frame
    else:
        step = len(joints_per_frame) / target
        rows = [joints_per_frame[int(i * step)] for i in range(target)]
    out = []
    for row in rows:
        compact = {"t": round(row["timestamp"], 3), "j": {}}
        for name, j in row["joints"].items():
            if j["confidence"] >= 0.3:
                compact["j"][name] = [round(j["x"], 3), round(j["y"], 3), round(j["confidence"], 2)]
        out.append(compact)
    return out


def _clip_duration_seconds(clip_bytes: bytes) -> float:
    try:
        import subprocess
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(clip_bytes)
            tmp = f.name
        try:
            out = subprocess.check_output(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", tmp],
                stderr=subprocess.DEVNULL,
            )
            return float(out.decode().strip())
        finally:
            os.unlink(tmp)
    except Exception:
        return 3.0


def _build_user_prompt(
    ios_type: str,
    clip_duration: float,
    trajectory: list[dict],
    handedness: str,
) -> str:
    dominant_side = "right" if handedness != "left" else "left"
    non_dominant_side = "left" if dominant_side == "right" else "right"
    return f"""## Clip context
- iOS on-device heuristic guessed this was a `{ios_type or 'unknown'}` stroke. This may be wrong. Treat it only as weak context.
- Player handedness is `{handedness or 'right'}`. Dominant side is `{dominant_side}`; non-dominant side is `{non_dominant_side}`.
- The clip is {clip_duration:.2f}s long. Contact appears near the middle.

## Joint trajectory (MediaPipe Pose, all 33 keypoints, sub-sampled)
Coordinates are normalized 0-1 of frame width/height. y increases downward (image space).
Confidence is MediaPipe's `visibility` score. Use these ACTUAL measured positions
together with the visual frames to determine stroke type and phase boundaries.

```json
{json.dumps(trajectory, separators=(",", ":"))}
```

## Stroke types
- `forehand`: dominant-side groundstroke. Dominant wrist moves from the player's dominant side into/through contact. For a right-handed player, this is usually contact on the player's right side; for a left-handed player, on the player's left side.
- `backhand`: non-dominant-side groundstroke. One- or two-handed. Dominant wrist crosses the body before/at contact. For a right-handed player, this is usually contact on the player's left side; for a left-handed player, on the player's right side.
- `serve`: overhead motion with upward toss/loading. Dominant wrist is above head/shoulder line around contact; non-dominant arm often rises before contact.
- `volley`: compact punch/block with little backswing. Wrist path is short, contact is in front of body, and there is minimal full groundstroke unit turn.
- `unknown`: ambiguous, occluded, or not actually a stroke.

## Evidence checklist
Before choosing `stroke_type`, compare:
- Dominant wrist side relative to shoulder/hip midpoint at contact.
- Dominant wrist height relative to nose/shoulders.
- Wrist path length and swing duration.
- Shoulder/hip rotation size.
- Whether the motion is overhead, compact volley, or full groundstroke.
Return only the JSON object, but base the one-sentence reasoning on this evidence.

## Seven phases (return clip-relative seconds)
1. `ready_position` — balanced, facing net, waiting.
2. `unit_turn` — shoulders + hips begin rotating toward the ball side. Racket starts moving back.
3. `backswing` — racket at peak of take-back. Loaded.
4. `forward_swing` — racket in motion toward ball, before contact.
5. `contact_point` — racket meets ball. Most identifiable moment. **Should align with peak wrist velocity in the trajectory.**
6. `follow_through` — racket past contact, decelerating.
7. `recovery` — player returning to neutral.

Constraints:
- All 7 timestamps MUST be strictly increasing.
- All within [0, {clip_duration:.2f}].
- Estimate even if a phase isn't clearly visible — never return null.

## Output schema (return this JSON exactly — no prose, no markdown)
{{
  "stroke_type": "forehand" | "backhand" | "serve" | "volley" | "unknown",
  "phases": {{
    "ready_position": <float seconds>,
    "unit_turn": <float>,
    "backswing": <float>,
    "forward_swing": <float>,
    "contact_point": <float>,
    "follow_through": <float>,
    "recovery": <float>
  }},
  "confidence": <float 0.0-1.0>,
  "reasoning": "<one sentence on the stroke-type call>"
}}
"""


class MediaPipeGeminiLabeler:
    name = "mediapipe_gemini"

    def __init__(self) -> None:
        settings = get_settings()
        try:
            from google import genai
        except ImportError as e:
            raise RuntimeError("google-genai package not installed") from e
        if not settings.gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY not set")
        self.client = genai.Client(api_key=settings.gemini_api_key)
        self.model = settings.gemini_model

    async def label(self, stroke: LabelerInput) -> LabelerResult:
        from google.genai import types

        started = time.perf_counter()

        # Extract MediaPipe trajectory (33 keypoints per frame)
        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(stroke.clip_bytes)
            mp_clip = f.name
        try:
            try:
                joints_per_frame = _extract_mediapipe_joints(mp_clip)
            except Exception as e:
                return LabelerResult(
                    stroke_type="unknown", phases={},
                    latency_ms=int((time.perf_counter() - started) * 1000),
                    error=f"mediapipe extraction failed: {type(e).__name__}: {e}",
                )
        finally:
            try:
                os.unlink(mp_clip)
            except OSError:
                pass

        if not joints_per_frame:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error="no joints extracted",
            )

        duration = joints_per_frame[-1]["timestamp"] if joints_per_frame else _clip_duration_seconds(stroke.clip_bytes)
        trajectory = _subsample_trajectory(joints_per_frame, TRAJECTORY_SAMPLE_COUNT)
        user_prompt = _build_user_prompt(
            stroke.ios_stroke_type,
            duration,
            trajectory,
            stroke.handedness,
        )

        contents: list = []
        try:
            if len(stroke.clip_bytes) > 20 * 1024 * 1024:
                with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
                    f.write(stroke.clip_bytes)
                    tmp = f.name
                try:
                    uploaded = self.client.files.upload(file=tmp)
                    contents.append(uploaded)
                finally:
                    os.unlink(tmp)
            else:
                contents.append(types.Part.from_bytes(
                    data=stroke.clip_bytes,
                    mime_type="video/mp4",
                ))
        except Exception as e:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=f"clip upload failed: {type(e).__name__}: {e}",
            )

        contents.append(user_prompt)

        try:
            response = self.client.models.generate_content(
                model=self.model,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=PHASE_DETECTOR_SYSTEM,
                    temperature=0.1,
                    max_output_tokens=2048,
                    response_mime_type="application/json",
                ),
            )
        except Exception as e:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=f"gemini call failed: {type(e).__name__}: {e}",
            )

        latency_ms = int((time.perf_counter() - started) * 1000)
        raw = response.text or ""

        usage = getattr(response, "usage_metadata", None)
        in_tok = getattr(usage, "prompt_token_count", None) if usage else None
        out_tok = getattr(usage, "candidates_token_count", None) if usage else None

        try:
            cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw.strip(), flags=re.MULTILINE)
            parsed = json.loads(cleaned)
        except json.JSONDecodeError as e:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=latency_ms, input_tokens=in_tok, output_tokens=out_tok,
                raw_response=raw[:500],
                error=f"json parse failed: {e}",
            )

        phases_clip_rel = parsed.get("phases", {}) or {}
        clip_start = stroke.clip_timestamp
        phases_abs = {
            k: float(v) + clip_start
            for k, v in phases_clip_rel.items()
            if isinstance(v, (int, float))
        }

        return LabelerResult(
            stroke_type=parsed.get("stroke_type", "unknown"),
            phases=phases_abs,
            latency_ms=latency_ms,
            input_tokens=in_tok,
            output_tokens=out_tok,
            confidence=parsed.get("confidence"),
            raw_response=raw[:2000],
        )


try:
    register(MediaPipeGeminiLabeler())
except Exception as e:
    logger.warning(f"MediaPipe-Gemini labeler unavailable: {e}")
