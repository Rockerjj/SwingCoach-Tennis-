"""Labeler C: Claude Opus 4.7 re-labels stroke type + phases from frame batch.

Claude can't consume video natively like Gemini, so we sample N evenly spaced
frames from the clip via ffmpeg and send them as images through the tool-use API.
Model returns frame indices; we convert back to session-absolute timestamps.
"""
from __future__ import annotations

import base64
import logging
import os
import subprocess
import tempfile
import time

from app.config import get_settings
from app.prompts.phase_detector_claude import (
    LABEL_STROKE_TOOL,
    PHASE_DETECTOR_SYSTEM,
    build_user_message,
)

from . import Labeler, LabelerInput, LabelerResult, register

logger = logging.getLogger(__name__)


FRAME_COUNT = 15


def _extract_frames(clip_bytes: bytes, count: int) -> tuple[list[bytes], float]:
    """Extract `count` evenly spaced JPEG frames from clip bytes.

    Returns (frames, clip_duration_seconds). Requires ffmpeg on PATH.
    """
    with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
        f.write(clip_bytes)
        clip_path = f.name
    frame_dir = tempfile.mkdtemp(prefix="labeler_frames_")
    try:
        # Probe duration
        try:
            out = subprocess.check_output(
                ["ffprobe", "-v", "error", "-show_entries", "format=duration",
                 "-of", "default=noprint_wrappers=1:nokey=1", clip_path],
                stderr=subprocess.DEVNULL,
            )
            duration = float(out.decode().strip())
        except Exception:
            duration = 3.0

        # Extract via fps filter — `count` frames evenly across the clip
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


class ClaudeFramesLabeler:
    name = "claude"

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

        try:
            frames, duration = _extract_frames(stroke.clip_bytes, FRAME_COUNT)
        except Exception as e:
            return LabelerResult(
                stroke_type="unknown",
                phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=f"frame extraction failed: {type(e).__name__}: {e}",
            )

        if not frames:
            return LabelerResult(
                stroke_type="unknown",
                phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error="no frames extracted",
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
            "text": build_user_message(stroke.ios_stroke_type, duration, len(frames)),
        })

        # Opus 4.7 deprecated the temperature parameter; older Sonnet models still accept it.
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
                stroke_type="unknown",
                phases={},
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
                stroke_type="unknown",
                phases={},
                latency_ms=latency_ms,
                input_tokens=in_tok,
                output_tokens=out_tok,
                error="no tool_use block in response",
            )

        data = tool_use.input or {}
        phase_frame_idxs = data.get("phases", {}) or {}

        # Convert frame index -> clip-relative seconds -> session-absolute seconds
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
            raw_response=str(data)[:2000],
        )


try:
    register(ClaudeFramesLabeler())
except Exception as e:
    logger.warning(f"Claude labeler unavailable: {e}")
