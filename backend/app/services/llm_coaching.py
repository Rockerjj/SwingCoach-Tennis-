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
from app.prompts.coaching_cues import format_cues_for_prompt

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

        max_images = 12
        image_detail = "high"

        for img_bytes in key_frame_images[:max_images]:
            try:
                resized = self._resize_image(img_bytes, max_size=1024)
                b64 = base64.b64encode(resized).decode("utf-8")
                content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/jpeg;base64,{b64}",
                        "detail": image_detail,
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
                {"role": "system", "content": SYSTEM_PROMPT + "\n\n## APPROVED COACHING CUES\nWhen giving coaching cues and drills, select from or closely adapt the following vetted cues. Do not invent novel biomechanical advice. Each cue has been reviewed for accuracy.\n" + format_cues_for_prompt()},
                {"role": "user", "content": content},
            ],
            response_format={"type": "json_object"},
            temperature=0.3,
            max_tokens=32000,
        )

        choice = response.choices[0]
        raw_json = choice.message.content
        finish_reason = choice.finish_reason
        refusal = getattr(choice.message, 'refusal', None)

        logger.info(
            f"LLM response received, tokens used: {response.usage.total_tokens}, "
            f"finish_reason={finish_reason}, refusal={refusal}, "
            f"content_length={len(raw_json) if raw_json else 0}"
        )

        if refusal:
            logger.error(f"LLM refused the request: {refusal}")
            raise ValueError(f"LLM refused to analyze: {refusal}")

        if not raw_json or not raw_json.strip():
            logger.error(f"LLM returned empty content. finish_reason={finish_reason}")
            raise ValueError(f"LLM returned empty response (finish_reason={finish_reason})")

        try:
            parsed = json.loads(raw_json)
            return AnalysisResponse(**parsed)
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse LLM JSON: {e}\nRaw: {raw_json[:1000]}")
            raise ValueError(f"LLM returned invalid JSON: {e}")
        except Exception as e:
            logger.error(f"Failed to validate response: {e}\nRaw: {raw_json[:1000]}")
            raise ValueError(f"LLM response didn't match schema: {e}")

    def _resize_image(self, img_bytes: bytes, max_size: int = 1024) -> bytes:
        img = Image.open(BytesIO(img_bytes))
        img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=75)
        return buffer.getvalue()
