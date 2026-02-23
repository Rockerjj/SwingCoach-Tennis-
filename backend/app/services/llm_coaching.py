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
    build_pose_summary,
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
        frames_dict = [f.model_dump() for f in pose_payload.frames]
        pose_summary = build_pose_summary(frames_dict)

        key_timestamps = ", ".join(
            f"{t:.2f}s" for t in pose_payload.key_frame_timestamps
        )

        user_prompt = ANALYSIS_PROMPT_TEMPLATE.format(
            skill_level=pose_payload.skill_level,
            duration_seconds=pose_payload.duration_seconds,
            frame_count=len(pose_payload.frames),
            fps=pose_payload.fps,
            pose_summary=pose_summary,
            key_frame_timestamps=key_timestamps or "None detected",
        )

        # Build message content with text + images
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
            f"Sending analysis request: {len(pose_payload.frames)} frames, "
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
            max_tokens=6000,
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
