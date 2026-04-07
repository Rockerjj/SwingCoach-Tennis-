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

logger = logging.getLogger(__name__)


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
                system_instruction=SYSTEM_PROMPT,
                temperature=0.3,
                max_output_tokens=32000,
                response_mime_type="application/json",
            ),
        )

        raw_json = response.text

        logger.info(
            f"Gemini response received, "
            f"content_length={len(raw_json) if raw_json else 0}"
        )

        if not raw_json or not raw_json.strip():
            raise ValueError("Gemini returned empty response")

        try:
            parsed = json.loads(raw_json)
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
