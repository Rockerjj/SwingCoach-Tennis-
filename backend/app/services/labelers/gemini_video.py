"""Labeler B: Gemini 2.5 Pro re-labels stroke type + phase timestamps from the clip.

Uses native video understanding via the `google-genai` SDK. Ships the clip
inline for <20MB, uses File API above that (matches gemini_coaching.py).
"""
from __future__ import annotations

import json
import logging
import os
import re
import tempfile
import time

from app.config import get_settings
from app.prompts.phase_detector_gemini import PHASE_DETECTOR_SYSTEM, build_user_prompt

from . import Labeler, LabelerInput, LabelerResult, register

logger = logging.getLogger(__name__)


def _clip_duration_seconds(clip_bytes: bytes) -> float:
    """Best-effort probe of clip duration via ffprobe; fall back to a safe default."""
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
        # Captured clips are ~3s (±1.5s around contact). Safe default.
        return 3.0


class GeminiVideoLabeler:
    name = "gemini"

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
        duration = _clip_duration_seconds(stroke.clip_bytes)
        user_prompt = build_user_prompt(stroke.ios_stroke_type, duration)

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
                stroke_type="unknown",
                phases={},
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
                stroke_type="unknown",
                phases={},
                latency_ms=int((time.perf_counter() - started) * 1000),
                error=f"gemini call failed: {type(e).__name__}: {e}",
            )

        latency_ms = int((time.perf_counter() - started) * 1000)
        raw = response.text or ""

        usage = getattr(response, "usage_metadata", None)
        in_tok = getattr(usage, "prompt_token_count", None) if usage else None
        out_tok = getattr(usage, "candidates_token_count", None) if usage else None

        # Parse. Gemini sometimes wraps in markdown fences even with JSON mime type.
        try:
            cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw.strip(), flags=re.MULTILINE)
            parsed = json.loads(cleaned)
        except json.JSONDecodeError as e:
            return LabelerResult(
                stroke_type="unknown",
                phases={},
                latency_ms=latency_ms,
                input_tokens=in_tok,
                output_tokens=out_tok,
                raw_response=raw[:500],
                error=f"json parse failed: {e}",
            )

        phases_clip_rel = parsed.get("phases", {}) or {}
        # Convert clip-relative timestamps back to session-absolute, to compare
        # like-for-like against ground truth + iOS labels which are session-absolute.
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
            raw_response=raw[:2000],
        )


try:
    register(GeminiVideoLabeler())
except Exception as e:
    logger.warning(f"Gemini labeler unavailable: {e}")
