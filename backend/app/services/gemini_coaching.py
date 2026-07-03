from __future__ import annotations

import json
import base64
import logging
import tempfile
import os

from app.config import get_settings
from app.models import AnalysisResponse, SessionPosePayload
from app.prompts.tennis_coach import (
    SYSTEM_PROMPT,
    ANALYSIS_PROMPT_TEMPLATE,
    build_detected_strokes_summary,
)
from app.prompts.coaching_cues import format_cues_for_prompt

logger = logging.getLogger(__name__)


def _coerce_to_response_shape(parsed):
    """Normalize whatever an LLM returns into the AnalysisResponse object shape.

    Handles four observed quirks across providers:
    - Gemini occasionally returns a JSON list at the root, either a 1-element
      list wrapping the full response or a bare list of stroke entries.
    - Opus 4.7 wraps the tool input in a top-level 'parameter' key, producing
      {'parameter': {<actual fields>}} instead of the fields directly.
    - Some models emit snake_case tool schema property {'AnalysisResponse': {...}}.
    - Models may omit optional fields entirely (handled by schema defaults).
    """
    # Opus 4.7 'parameter' wrapper: unwrap if the dict has exactly one key
    # whose value is a dict with AnalysisResponse-shaped fields.
    if isinstance(parsed, dict) and len(parsed) == 1:
        only_key = next(iter(parsed.keys()))
        only_val = parsed[only_key]
        response_keys = {"session_grade", "strokes_detected", "overall_mechanics_score"}
        if (
            only_key in ("parameter", "input", "AnalysisResponse", "analysis")
            and isinstance(only_val, dict)
            and response_keys & set(only_val.keys())
        ):
            logger.warning(
                f"Model wrapped tool input under single key {only_key!r}; unwrapped"
            )
            parsed = only_val
    if isinstance(parsed, list):
        # Order matters: detect stroke-list shape BEFORE the 1-element-unwrap case,
        # since a 1-element list could be either a wrapped AnalysisResponse or a
        # 1-stroke list. Distinguish by looking for AnalysisResponse-only keys.
        all_dicts = parsed and all(isinstance(x, dict) for x in parsed)
        looks_like_strokes = all_dicts and all(
            "type" in x and "session_grade" not in x and "strokes_detected" not in x
            for x in parsed
        )
        if looks_like_strokes:
            logger.warning(
                f"Gemini returned bare list of {len(parsed)} stroke-like entries; "
                "wrapping into AnalysisResponse with empty session fields"
            )
            parsed = {
                "session_grade": "Incomplete",
                "strokes_detected": parsed,
                "tactical_notes": [],
                "top_priority": "",
                "overall_mechanics_score": 0.0,
                "session_summary": "",
            }
        elif len(parsed) == 1 and isinstance(parsed[0], dict):
            parsed = parsed[0]
            logger.warning("Gemini wrapped response in 1-element list; unwrapped")
        else:
            first_keys = list(parsed[0].keys())[:5] if parsed and isinstance(parsed[0], dict) else "n/a"
            raise ValueError(
                f"Gemini returned a JSON list of unrecognized shape "
                f"(len={len(parsed)}, first_keys={first_keys})"
            )
    if not isinstance(parsed, dict):
        raise ValueError(f"Gemini response must be object or list, got {type(parsed).__name__}")
    return parsed


class GeminiCoachingService:
    """Coaching analysis using Gemini 2.5 Pro with native video understanding."""

    def __init__(self):
        settings = get_settings()
        try:
            from google import genai
            self.client = genai.Client(api_key=settings.gemini_api_key)
        except ImportError:
            raise RuntimeError("google-genai package not installed")
        self.model = settings.gemini_model
        # Populated after each analyze_session call so the eval harness and
        # cost tracker can read token counts without re-running the request.
        self.last_usage: dict | None = None

    async def analyze_session(
        self,
        pose_payload: SessionPosePayload,
        key_frame_images: list[bytes],
        video_clips: list[tuple[float, bytes]] | None = None,
    ) -> AnalysisResponse:
        from google.genai import types

        detected_strokes_dicts = [s.model_dump() for s in pose_payload.detected_strokes]
        strokes_summary = build_detected_strokes_summary(detected_strokes_dicts)

        handedness = getattr(pose_payload, "handedness", "right")
        dominant_side = "left" if handedness == "left" else "right"

        user_prompt = ANALYSIS_PROMPT_TEMPLATE.format(
            skill_level=pose_payload.skill_level,
            handedness=handedness,
            dominant_side=dominant_side,
            duration_seconds=pose_payload.duration_seconds,
            stroke_count=len(pose_payload.detected_strokes),
            detected_strokes_summary=strokes_summary,
        )

        contents: list = []

        # Add video clips if provided (Gemini's native video understanding)
        if video_clips:
            for timestamp, clip_bytes in video_clips:
                try:
                    # Upload via File API for clips > 20MB, inline for smaller ones
                    if len(clip_bytes) > 20 * 1024 * 1024:
                        uploaded = self._upload_clip(clip_bytes, timestamp)
                        contents.append(uploaded)
                    else:
                        contents.append(types.Part.from_bytes(
                            data=clip_bytes,
                            mime_type="video/mp4",
                        ))
                    logger.info(f"Added video clip at t={timestamp:.1f}s ({len(clip_bytes)} bytes)")
                except Exception as e:
                    logger.warning(f"Failed to add video clip at t={timestamp:.1f}s: {e}")

        # Add key frame images as fallback / supplementary context
        max_images = 12
        for img_bytes in key_frame_images[:max_images]:
            try:
                contents.append(types.Part.from_bytes(
                    data=img_bytes,
                    mime_type="image/jpeg",
                ))
            except Exception as e:
                logger.warning(f"Failed to add key frame image: {e}")

        # Add the text prompt last
        contents.append(user_prompt)

        clip_count = len(video_clips) if video_clips else 0
        logger.info(
            f"Sending Gemini analysis: {len(pose_payload.detected_strokes)} strokes, "
            f"{clip_count} video clips, {len(key_frame_images)} images, model={self.model}"
        )

        response = self.client.models.generate_content(
            model=self.model,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT + "\n\n## APPROVED COACHING CUES\nWhen giving coaching cues and drills, select from or closely adapt the following vetted cues. Do not invent novel biomechanical advice. Each cue has been reviewed for accuracy.\n" + format_cues_for_prompt(),
                temperature=0.3,
                max_output_tokens=32000,
                response_mime_type="application/json",
            ),
        )

        raw_json = response.text

        usage = getattr(response, "usage_metadata", None)
        if usage is not None:
            self.last_usage = {
                "input_tokens": getattr(usage, "prompt_token_count", None),
                "output_tokens": getattr(usage, "candidates_token_count", None),
            }

        logger.info(
            f"Gemini response received, "
            f"content_length={len(raw_json) if raw_json else 0}, "
            f"usage={self.last_usage}"
        )

        if not raw_json or not raw_json.strip():
            raise ValueError("Gemini returned empty response")

        try:
            parsed = json.loads(raw_json)
            parsed = _coerce_to_response_shape(parsed)
            return AnalysisResponse(**parsed)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Gemini JSON: {e}\nRaw: {raw_json[:1000]}")
            raise ValueError(f"Gemini returned invalid JSON: {e}")
        except Exception as e:
            logger.error(f"Failed to validate response: {e}\nRaw: {raw_json[:1000]}")
            raise ValueError(f"Gemini response didn't match schema: {e}")

    def _upload_clip(self, clip_bytes: bytes, timestamp: float):
        """Upload large clips via the Gemini File API."""
        from google.genai import types

        with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
            f.write(clip_bytes)
            tmp_path = f.name
        try:
            uploaded = self.client.files.upload(file=tmp_path)
            return uploaded
        finally:
            os.unlink(tmp_path)
