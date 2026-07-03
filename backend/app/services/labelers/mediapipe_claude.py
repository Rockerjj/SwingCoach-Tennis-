"""Labeler F: MediaPipe joint trajectories + Claude Opus 4.7 vision.

Hybrid approach: Claude sees BOTH the visual frames AND the per-frame joint
positions extracted by MediaPipe. Hypothesis: this dramatically beats either
heuristic-on-joints OR vision-on-frames alone, because Claude can correlate
what it sees with the measured kinematics instead of having to infer them.

Sends a compact JSON of the joint trajectory (sub-sampled) alongside the same
15-frame batch the existing Claude labeler uses.
"""
from __future__ import annotations

import base64
import json
import logging
import os
import subprocess
import tempfile
import time

from app.config import get_settings
from app.prompts.phase_detector_claude import LABEL_STROKE_TOOL, PHASE_DETECTOR_SYSTEM

from . import Labeler, LabelerInput, LabelerResult, register
from .mediapipe_heuristic import _extract_mediapipe_joints

logger = logging.getLogger(__name__)


FRAME_COUNT = 15  # match base claude_frames labeler
TRAJECTORY_SAMPLE_COUNT = 30  # joint frames sent to Claude (one row per ~0.1s for a 3s clip)


def _build_user_message_with_trajectory(
    ios_type: str,
    clip_duration: float,
    frame_count: int,
    trajectory: list[dict],
    handedness: str,
) -> str:
    dominant_side = "right" if handedness != "left" else "left"
    non_dominant_side = "left" if dominant_side == "right" else "right"
    return f"""## Clip context
- iOS on-device heuristic guessed this was a `{ios_type or 'unknown'}` stroke. Treat it only as weak context.
- Player handedness is `{handedness or 'right'}`. Dominant side is `{dominant_side}`; non-dominant side is `{non_dominant_side}`.
- You are seeing {frame_count} evenly spaced frames covering a {clip_duration:.2f}s clip.
- Frame 0 is at t=0.00s; frame {frame_count - 1} is at t={clip_duration:.2f}s.

## Joint trajectory (MediaPipe Pose, per-frame coordinates)
Coordinates are normalized 0-1 of frame width/height. y increases downward.
Confidence is MediaPipe's `visibility` score (1.0 = fully visible). Use these
ACTUAL measured positions to determine stroke type and phase boundaries —
do not just rely on the visual frames.

```json
{json.dumps(trajectory, separators=(",", ":"))}
```

## Your job
Identify the stroke type and the 7 swing phases.

## Stroke types
- `forehand`, `backhand`, `serve`, `volley`, `unknown`

Disambiguation:
- Forehand is dominant-side groundstroke contact.
- Backhand is non-dominant-side groundstroke contact, one- or two-handed.
- Serve is overhead with wrist above head/shoulder line and toss/loading motion.
- Volley is compact punch/block with minimal backswing and short wrist path.

## Seven phases (in temporal order)
ready_position → unit_turn → backswing → forward_swing → contact_point → follow_through → recovery

Rules:
- Phase frame indices MUST be strictly increasing.
- Use the joint trajectory to place phases precisely. Contact_point = peak wrist velocity.

Call the `label_stroke` tool with your answer. Do not reply with prose.
"""


def _extract_frames(clip_bytes: bytes, count: int) -> tuple[list[bytes], float]:
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
        f.write(clip_bytes)
        clip_path = f.name
    frame_dir = tempfile.mkdtemp(prefix="mpc_frames_")
    try:
        try:
            out = subprocess.check_output(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", clip_path],
                stderr=subprocess.DEVNULL,
            )
            duration = float(out.decode().strip())
        except Exception:
            duration = 3.0
        fps = max(count / max(duration, 0.1), 0.1)
        subprocess.check_call(
            ["ffmpeg", "-y", "-i", clip_path,
             "-vf", f"fps={fps},scale=512:-2",
             "-vframes", str(count),
             "-q:v", "3",
             os.path.join(frame_dir, "frame_%03d.jpg")],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        frames: list[bytes] = []
        for name in sorted(os.listdir(frame_dir)):
            if name.endswith(".jpg"):
                with open(os.path.join(frame_dir, name), "rb") as f:
                    frames.append(f.read())
        return frames, duration
    finally:
        try:
            os.unlink(clip_path)
        except OSError:
            pass
        for name in os.listdir(frame_dir):
            try:
                os.unlink(os.path.join(frame_dir, name))
            except OSError:
                pass
        try:
            os.rmdir(frame_dir)
        except OSError:
            pass


def _subsample_trajectory(joints_per_frame: list[dict], target: int) -> list[dict]:
    """Reduce per-frame joint dicts to `target` evenly spaced frames, with rounded coords."""
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


class MediaPipeClaudeLabeler:
    name = "mediapipe_claude"

    def __init__(self) -> None:
        settings = get_settings()
        try:
            import anthropic  # noqa: F401
        except ImportError as e:
            raise RuntimeError("anthropic package not installed") from e
        if not settings.anthropic_api_key:
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        from anthropic import AsyncAnthropic
        self.client = AsyncAnthropic(api_key=settings.anthropic_api_key)
        self.model = settings.anthropic_opus_model

    async def label(self, stroke: LabelerInput) -> LabelerResult:
        started = time.perf_counter()

        # Extract MediaPipe trajectory from the clip
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

        trajectory = _subsample_trajectory(joints_per_frame, TRAJECTORY_SAMPLE_COUNT)

        # Extract visual frames for Claude
        try:
            frames, duration = _extract_frames(stroke.clip_bytes, FRAME_COUNT)
        except Exception as e:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=f"frame extraction failed: {type(e).__name__}: {e}",
            )

        user_content: list[dict] = []
        for i, img_bytes in enumerate(frames):
            user_content.append({
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64.b64encode(img_bytes).decode("ascii"),
                },
            })
            user_content.append({"type": "text", "text": f"frame {i}"})
        user_content.append({
            "type": "text",
            "text": _build_user_message_with_trajectory(
                stroke.ios_stroke_type, duration, len(frames), trajectory, stroke.handedness,
            ),
        })

        kwargs = dict(
            model=self.model,
            max_tokens=1024,
            system=PHASE_DETECTOR_SYSTEM,
            tools=[LABEL_STROKE_TOOL],
            tool_choice={"type": "tool", "name": "label_stroke"},
            messages=[{"role": "user", "content": user_content}],
        )
        if "opus-4-7" not in self.model:
            kwargs["temperature"] = 0.1

        try:
            response = await self.client.messages.create(**kwargs)
        except Exception as e:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=f"claude call failed: {type(e).__name__}: {e}",
            )

        latency_ms = int((time.perf_counter() - started) * 1000)
        in_tok = response.usage.input_tokens if getattr(response, "usage", None) else None
        out_tok = response.usage.output_tokens if getattr(response, "usage", None) else None

        tool_use = next(
            (b for b in response.content if getattr(b, "type", None) == "tool_use"),
            None,
        )
        if tool_use is None:
            return LabelerResult(
                stroke_type="unknown", phases={},
                latency_ms=latency_ms, input_tokens=in_tok, output_tokens=out_tok,
                error="no tool_use block in response",
            )

        data = tool_use.input or {}
        phase_frame_idxs = data.get("phases", {}) or {}

        n = len(frames)
        clip_start = stroke.clip_timestamp
        phases_abs = {}
        for name, idx in phase_frame_idxs.items():
            if not isinstance(idx, int):
                continue
            clip_rel = (idx / max(n - 1, 1)) * duration
            phases_abs[name] = clip_start + clip_rel

        return LabelerResult(
            stroke_type=data.get("stroke_type", "unknown"),
            phases=phases_abs,
            latency_ms=latency_ms,
            input_tokens=in_tok,
            output_tokens=out_tok,
            confidence=data.get("confidence"),
            raw_response=str(data)[:2000],
        )


try:
    register(MediaPipeClaudeLabeler())
except Exception as e:
    logger.warning(f"MediaPipe-Claude labeler unavailable: {e}")
