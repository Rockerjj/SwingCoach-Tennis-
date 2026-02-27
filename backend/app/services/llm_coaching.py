import json
import base64
import logging
from io import BytesIO
from openai import AsyncOpenAI
from PIL import Image

from app.config import get_settings
from app.models import AnalysisResponse, SessionPosePayload
from app.prompts.tennis_coach import (
    SYSTEM_PROMPT,
    ANALYSIS_PROMPT_TEMPLATE,
    build_detected_strokes_summary,
)

logger = logging.getLogger(__name__)


class LLMCoachingService:
    def __init__(self):
        settings = get_settings()
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.openai_model

    async def analyze_session(
        self,
        pose_payload: SessionPosePayload,
        key_frame_images: list[bytes],
    ) -> AnalysisResponse:
        detected_strokes_dicts = [s.model_dump() for s in pose_payload.detected_strokes]
        strokes_summary = build_detected_strokes_summary(detected_strokes_dicts)

        handedness = getattr(pose_payload, 'handedness', 'right')
        dominant_side = "left" if handedness == "left" else "right"

        user_prompt = ANALYSIS_PROMPT_TEMPLATE.format(
            skill_level=pose_payload.skill_level,
            handedness=handedness,
            dominant_side=dominant_side,
            duration_seconds=pose_payload.duration_seconds,
            stroke_count=len(pose_payload.detected_strokes),
            detected_strokes_summary=strokes_summary,
        )

        content: list[dict] = [{"type": "text", "text": user_prompt}]

        for img_bytes in key_frame_images[:10]:
            try:
                resized = self._resize_image(img_bytes, max_size=512)
                b64 = base64.b64encode(resized).decode("utf-8")
                content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{b64}",
                        "detail": "low",
                    },
                })
            except Exception as e:
                logger.warning(f"Failed to process key frame image: {e}")

        logger.info(
            f"Sending analysis request: {len(pose_payload.detected_strokes)} pre-detected strokes, "
            f"{len(key_frame_images)} images, model={self.model}"
        )

        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": content},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            max_tokens=8000,
        )

        raw_json = response.choices[0].message.content
        logger.info(f"LLM response received, tokens used: {response.usage.total_tokens}")

        try:
            parsed = json.loads(raw_json)
            return AnalysisResponse(**parsed)
        except (json.JSONDecodeError, Exception) as e:
            logger.error(f"Failed to parse LLM response: {e}\nRaw: {raw_json[:500]}")
            raise ValueError(f"LLM returned invalid analysis format: {e}")

    def _resize_image(self, img_bytes: bytes, max_size: int = 512) -> bytes:
        img = Image.open(BytesIO(img_bytes))
        img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=75)
        return buffer.getvalue()
