import json
import base64
import asyncio
import logging
from io import BytesIO
from uuid import uuid4
from openai import AsyncOpenAI
from PIL import Image

from app.config import get_settings
from app.models import AnalysisResponse, SessionPosePayload
from app.prompts.tennis_coach import (
    SYSTEM_PROMPT,
    ANALYSIS_PROMPT_TEMPLATE,
    build_detected_strokes_summary,
    get_stroke_types_from_payload,
)

logger = logging.getLogger(__name__)

# JSON Schema for structured outputs — enforces AnalysisResponse shape
ANALYSIS_RESPONSE_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "AnalysisResponse",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "session_grade": {"type": "string"},
                "session_summary": {"type": "string"},
                "top_priority": {"type": "string"},
                "overall_mechanics_score": {"type": "number"},
                "tactical_notes": {
                    "type": "array",
                    "items": {"type": "string"}
                },
                "strokes_detected": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "type": {"type": "string"},
                            "timestamp": {"type": "number"},
                            "grade": {"type": "string"},
                            "grading_rationale": {"type": "string"},
                            "next_reps_plan": {"type": "string"},
                            "verified_sources": {
                                "type": "array",
                                "items": {"type": "string"}
                            },
                            "mechanics": {
                                "type": "object",
                                "properties": {
                                    "backswing": {"$ref": "#/$defs/MechanicDetail"},
                                    "contact_point": {"$ref": "#/$defs/MechanicDetail"},
                                    "follow_through": {"$ref": "#/$defs/MechanicDetail"},
                                    "stance": {"$ref": "#/$defs/MechanicDetail"},
                                    "toss": {"$ref": "#/$defs/MechanicDetail"}
                                },
                                "additionalProperties": False
                            },
                            "phase_breakdown": {
                                "type": "object",
                                "properties": {
                                    "ready_position": {"$ref": "#/$defs/PhaseDetail"},
                                    "unit_turn": {"$ref": "#/$defs/PhaseDetail"},
                                    "backswing": {"$ref": "#/$defs/PhaseDetail"},
                                    "forward_swing": {"$ref": "#/$defs/PhaseDetail"},
                                    "contact_point": {"$ref": "#/$defs/PhaseDetail"},
                                    "follow_through": {"$ref": "#/$defs/PhaseDetail"},
                                    "recovery": {"$ref": "#/$defs/PhaseDetail"}
                                },
                                "additionalProperties": False
                            },
                            "analysis_categories": {
                                "type": "array",
                                "items": {"$ref": "#/$defs/AnalysisCategory"}
                            },
                            "overlay_instructions": {
                                "type": "object",
                                "properties": {
                                    "angles_to_highlight": {
                                        "type": "array",
                                        "items": {"type": "string"}
                                    },
                                    "trajectory_line": {"type": "boolean"},
                                    "comparison_ghost": {"type": "boolean"}
                                },
                                "required": ["angles_to_highlight", "trajectory_line", "comparison_ghost"],
                                "additionalProperties": False
                            }
                        },
                        "required": [
                            "type", "timestamp", "grade", "grading_rationale",
                            "next_reps_plan", "verified_sources", "mechanics",
                            "phase_breakdown", "analysis_categories", "overlay_instructions"
                        ],
                        "additionalProperties": False
                    }
                }
            },
            "required": [
                "session_grade", "session_summary", "top_priority",
                "overall_mechanics_score", "tactical_notes", "strokes_detected"
            ],
            "additionalProperties": False,
            "$defs": {
                "MechanicDetail": {
                    "anyOf": [
                        {
                            "type": "object",
                            "properties": {
                                "score": {"type": "integer"},
                                "note": {"type": "string"},
                                "why_score": {"type": "string"},
                                "improve_cue": {"type": "string"},
                                "drill": {"type": "string"},
                                "sources": {"type": "array", "items": {"type": "string"}}
                            },
                            "required": ["score", "note", "why_score", "improve_cue", "drill", "sources"],
                            "additionalProperties": False
                        },
                        {"type": "null"}
                    ]
                },
                "PhaseDetail": {
                    "anyOf": [
                        {
                            "type": "object",
                            "properties": {
                                "score": {"type": "integer"},
                                "status": {"type": "string", "enum": ["in_zone", "warning", "out_of_zone"]},
                                "note": {"type": "string"},
                                "timestamp": {"type": "number"},
                                "key_angles": {"type": "array", "items": {"type": "string"}},
                                "improve_cue": {"type": "string"},
                                "drill": {"type": "string"}
                            },
                            "required": ["score", "status", "note", "timestamp", "key_angles", "improve_cue", "drill"],
                            "additionalProperties": False
                        },
                        {"type": "null"}
                    ]
                },
                "AnalysisCategory": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "description": {"type": "string"},
                        "status": {"type": "string", "enum": ["in_zone", "warning", "out_of_zone"]},
                        "thumbnail_phase": {"type": "string"},
                        "subchecks": {
                            "type": "array",
                            "items": {
                                "type": "object",
                                "properties": {
                                    "checkpoint": {"type": "string"},
                                    "result": {"type": "string"},
                                    "status": {"type": "string", "enum": ["in_zone", "warning", "out_of_zone"]}
                                },
                                "required": ["checkpoint", "result", "status"],
                                "additionalProperties": False
                            }
                        }
                    },
                    "required": ["name", "description", "status", "thumbnail_phase", "subchecks"],
                    "additionalProperties": False
                }
            }
        }
    }
}

_FALLBACK_RESPONSE = AnalysisResponse(
    session_grade="N/A",
    session_summary="Analysis could not be completed due to a processing error. Please try again.",
    top_priority="Re-record your session and try again.",
    overall_mechanics_score=0.0,
    tactical_notes=["Analysis unavailable — please retry."],
    strokes_detected=[],
)


class LLMCoachingService:
    MAX_RETRIES = 3
    RETRY_BASE_DELAY = 2.0  # seconds, doubles each retry

    def __init__(self):
        settings = get_settings()
        self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.openai_model

    async def analyze_session(
        self,
        pose_payload: SessionPosePayload,
        key_frame_images: list[bytes],
        request_id: str | None = None,
    ) -> AnalysisResponse:
        request_id = request_id or str(uuid4())[:8]
        log = logging.LoggerAdapter(logger, {"request_id": request_id})

        detected_strokes_dicts = [s.model_dump() for s in pose_payload.detected_strokes]
        stroke_types = get_stroke_types_from_payload(detected_strokes_dicts)
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
            stroke_specific_context=_build_stroke_context_block(stroke_types),
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
                log.warning(f"Failed to process key frame image: {e}")

        log.info(
            f"[{request_id}] Sending analysis: {len(pose_payload.detected_strokes)} strokes, "
            f"{len(key_frame_images)} images, model={self.model}, "
            f"stroke_types={stroke_types}"
        )

        last_error: Exception | None = None
        for attempt in range(1, self.MAX_RETRIES + 1):
            try:
                response = await self.client.chat.completions.create(
                    model=self.model,
                    messages=[
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": content},
                    ],
                    response_format=ANALYSIS_RESPONSE_SCHEMA,
                    temperature=0.3,
                    max_tokens=32000,
                )

                choice = response.choices[0]
                raw_json = choice.message.content
                finish_reason = choice.finish_reason
                refusal = getattr(choice.message, 'refusal', None)

                log.info(
                    f"[{request_id}] LLM response (attempt {attempt}): "
                    f"tokens={response.usage.total_tokens}, "
                    f"finish_reason={finish_reason}, refusal={refusal}, "
                    f"content_length={len(raw_json) if raw_json else 0}"
                )

                if refusal:
                    raise ValueError(f"LLM refused: {refusal}")

                if not raw_json or not raw_json.strip():
                    raise ValueError(f"LLM returned empty response (finish_reason={finish_reason})")

                try:
                    parsed = json.loads(raw_json)
                    return AnalysisResponse(**parsed)
                except json.JSONDecodeError as e:
                    log.error(f"[{request_id}] JSON parse error: {e}\nRaw (first 500): {raw_json[:500]}")
                    raise ValueError(f"Invalid JSON: {e}")
                except Exception as e:
                    log.error(f"[{request_id}] Schema validation error: {e}\nRaw (first 500): {raw_json[:500] if raw_json else 'None'}")
                    raise ValueError(f"Schema mismatch: {e}")

            except Exception as e:
                last_error = e
                if attempt < self.MAX_RETRIES:
                    delay = self.RETRY_BASE_DELAY * (2 ** (attempt - 1))
                    log.warning(f"[{request_id}] Attempt {attempt} failed: {e}. Retrying in {delay}s...")
                    await asyncio.sleep(delay)
                else:
                    log.error(f"[{request_id}] All {self.MAX_RETRIES} attempts failed. Last error: {e}")

        log.error(f"[{request_id}] Returning fallback response after all retries exhausted.")
        return _FALLBACK_RESPONSE

    def _resize_image(self, img_bytes: bytes, max_size: int = 1024) -> bytes:
        img = Image.open(BytesIO(img_bytes))
        img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        buffer = BytesIO()
        img.save(buffer, format="JPEG", quality=75)
        return buffer.getvalue()


def _build_stroke_context_block(stroke_types: set[str]) -> str:
    """Build stroke-specific biomechanical context to inject into the prompt."""
    from app.prompts.tennis_coach import STROKE_SPECIFIC_CONTEXT
    lines = []
    for stroke_type in sorted(stroke_types):
        ctx = STROKE_SPECIFIC_CONTEXT.get(stroke_type)
        if ctx:
            lines.append(f"### {stroke_type.title()} — Biomechanical Reference")
            lines.append(ctx)
    return "\n\n".join(lines) if lines else ""
