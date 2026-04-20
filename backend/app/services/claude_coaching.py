"""Anthropic Claude coaching service.

Mirrors the LLMCoachingService interface so the analyze route can dispatch
to it transparently. Uses Claude's tool use to enforce the AnalysisResponse
schema as structured output, which is more reliable than free-form JSON.

The same class serves both Opus and Sonnet via the `model` constructor arg.
"""
from __future__ import annotations

import base64
import logging
from io import BytesIO

from PIL import Image

from app.config import get_settings
from app.models import AnalysisResponse, SessionPosePayload
from app.prompts.tennis_coach_claude import (
    SYSTEM_PROMPT,
    ANALYSIS_PROMPT_TEMPLATE,
)
from app.prompts.tennis_coach import build_detected_strokes_summary
from app.prompts.coaching_cues import format_cues_for_prompt

logger = logging.getLogger(__name__)


# Single tool that Claude is forced to call. Its input schema IS the
# AnalysisResponse Pydantic model, so a successful tool call gives us
# a structurally-valid analysis without parsing JSON out of prose.
_ANALYSIS_TOOL_NAME = "submit_analysis"


def _build_analysis_tool() -> dict:
    schema = AnalysisResponse.model_json_schema()
    return {
        "name": _ANALYSIS_TOOL_NAME,
        "description": (
            "Submit the complete coaching analysis for this session. "
            "Call this exactly once with all required fields populated."
        ),
        "input_schema": schema,
    }


class ClaudeCoachingService:
    def __init__(self, model: str | None = None):
        settings = get_settings()
        try:
            from anthropic import AsyncAnthropic
        except ImportError as e:
            raise RuntimeError(
                "anthropic package not installed. Add `anthropic` to requirements.txt."
            ) from e

        if not settings.anthropic_api_key:
            raise RuntimeError("ANTHROPIC_API_KEY is not configured")

        self.client = AsyncAnthropic(api_key=settings.anthropic_api_key)
        # Default to Opus if no model passed; the route always passes one
        # explicitly so this fallback is just a safety net.
        self.model = model or settings.anthropic_opus_model
        # Populated after each analyze_session call so callers (eval harness,
        # cost tracker) can read token counts without re-running the request.
        self.last_usage: dict | None = None

    async def analyze_session(
        self,
        pose_payload: SessionPosePayload,
        key_frame_images: list[bytes],
    ) -> AnalysisResponse:
        detected_strokes_dicts = [s.model_dump() for s in pose_payload.detected_strokes]
        strokes_summary = build_detected_strokes_summary(detected_strokes_dicts)

        handedness = getattr(pose_payload, "handedness", "right")
        dominant_side = "left" if handedness == "left" else "right"

        user_text = ANALYSIS_PROMPT_TEMPLATE.format(
            skill_level=pose_payload.skill_level,
            handedness=handedness,
            dominant_side=dominant_side,
            duration_seconds=pose_payload.duration_seconds,
            stroke_count=len(pose_payload.detected_strokes),
            detected_strokes_summary=strokes_summary,
        )

        system = (
            SYSTEM_PROMPT
            + "\n\n<approved_coaching_cues>\n"
            + "When giving coaching cues and drills, select from or closely adapt the following "
            + "vetted cues. Do not invent novel biomechanical advice. Each cue has been reviewed for accuracy.\n\n"
            + format_cues_for_prompt()
            + "\n</approved_coaching_cues>"
        )

        # Build content blocks: keyframes first, then the analysis prompt.
        # Claude reads images in order, so leading with frames lets the
        # textual instructions reference what was just shown.
        max_images = 12
        content: list[dict] = []
        for img_bytes in key_frame_images[:max_images]:
            try:
                resized = self._resize_image(img_bytes, max_size=1024)
                b64 = base64.standard_b64encode(resized).decode("utf-8")
                content.append({
                    "type": "image",
                    "source": {
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": b64,
                    },
                })
            except Exception as e:
                logger.warning(f"Failed to process key frame image for Claude: {e}")

        content.append({"type": "text", "text": user_text})

        logger.info(
            f"Sending Claude analysis: {len(pose_payload.detected_strokes)} strokes, "
            f"{len(content) - 1} images, model={self.model}"
        )

        # Note: temperature is deprecated on the newer Claude models (Opus 4.7,
        # Sonnet 4.6+). The models' default sampling is well-calibrated for
        # structured output; we rely on tool-use to enforce the schema.
        response = await self.client.messages.create(
            model=self.model,
            max_tokens=16000,
            system=system,
            tools=[_build_analysis_tool()],
            tool_choice={"type": "tool", "name": _ANALYSIS_TOOL_NAME},
            messages=[{"role": "user", "content": content}],
        )

        usage = getattr(response, "usage", None)
        if usage is not None:
            self.last_usage = {
                "input_tokens": usage.input_tokens,
                "output_tokens": usage.output_tokens,
            }
            logger.info(
                f"Claude response received, "
                f"input_tokens={usage.input_tokens}, output_tokens={usage.output_tokens}, "
                f"stop_reason={response.stop_reason}"
            )

        # Find the tool_use block. Claude may also include a thinking text
        # block before the tool call; we ignore everything except the tool input.
        tool_input: dict | None = None
        for block in response.content:
            if getattr(block, "type", None) == "tool_use" and getattr(block, "name", None) == _ANALYSIS_TOOL_NAME:
                tool_input = block.input
                break

        if tool_input is None:
            stop_reason = getattr(response, "stop_reason", "unknown")
            raise ValueError(
                f"Claude did not call submit_analysis (stop_reason={stop_reason}). "
                f"Content blocks: {[getattr(b, 'type', '?') for b in response.content]}"
            )

        try:
            # Same coercion the Gemini path uses, so any LLM quirk we've already
            # learned to handle (nulls, accidentally-listed root) Just Works here.
            from app.services.gemini_coaching import _coerce_to_response_shape
            shaped = _coerce_to_response_shape(tool_input)
            return AnalysisResponse(**shaped)
        except Exception as e:
            logger.error(f"Claude tool input failed schema validation: {e}")
            raise ValueError(f"Claude response didn't match schema: {e}")

    def _resize_image(self, img_bytes: bytes, max_size: int = 1024) -> bytes:
        img = Image.open(BytesIO(img_bytes))
        if img.mode != "RGB":
            img = img.convert("RGB")
        img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=75)
        return buffer.getvalue()
