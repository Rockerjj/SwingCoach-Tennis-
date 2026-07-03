"""Prompt + tool schema for Claude Opus 4.7 frame-batch phase-detection bake-off labeler.

Claude consumes ~12 evenly spaced frames from the stroke clip (it can't watch video
natively the way Gemini can, so we downsample). The model picks stroke type and
identifies which frame each phase corresponds to; we convert frame index -> timestamp.
"""
from __future__ import annotations

# Reuse the same domain content as the Gemini prompt; only the envelope differs.
from .phase_detector_gemini import PHASE_DETECTOR_SYSTEM as _SHARED_SYSTEM


PHASE_DETECTOR_SYSTEM = _SHARED_SYSTEM + """
Because you are receiving still frames (not video), you must reason from the visual
progression across frames. Frame 0 is the clip's first moment; frame N-1 is the last.
"""


def build_user_message(ios_type: str, clip_duration: float, frame_count: int) -> str:
    return f"""## Clip context
- iOS on-device heuristic guessed this was a `{ios_type or 'unknown'}` stroke. You may disagree.
- You are seeing {frame_count} evenly spaced frames covering a {clip_duration:.2f}s clip.
- Frame 0 is at t=0.00s; frame {frame_count - 1} is at t={clip_duration:.2f}s. Intermediate frames are linearly spaced.

## Your job
Identify the stroke type and the 7 swing phases.

## Stroke types
- `forehand`, `backhand`, `serve`, `volley`, `unknown`

## Seven phases (in temporal order)
ready_position → unit_turn → backswing → forward_swing → contact_point → follow_through → recovery

Rules:
- Phase frame indices MUST be strictly increasing.
- If a phase is not clearly shown, pick the nearest visible frame — never skip.

Call the `label_stroke` tool with your answer. Do not reply with prose.
"""


LABEL_STROKE_TOOL = {
    "name": "label_stroke",
    "description": "Submit the stroke type and per-phase frame indices for this clip.",
    "input_schema": {
        "type": "object",
        "properties": {
            "stroke_type": {
                "type": "string",
                "enum": ["forehand", "backhand", "serve", "volley", "unknown"],
            },
            "phases": {
                "type": "object",
                "properties": {
                    "ready_position": {"type": "integer", "description": "Frame index (0-based)"},
                    "unit_turn": {"type": "integer"},
                    "backswing": {"type": "integer"},
                    "forward_swing": {"type": "integer"},
                    "contact_point": {"type": "integer"},
                    "follow_through": {"type": "integer"},
                    "recovery": {"type": "integer"},
                },
                "required": [
                    "ready_position", "unit_turn", "backswing", "forward_swing",
                    "contact_point", "follow_through", "recovery",
                ],
            },
            "confidence": {"type": "number", "minimum": 0.0, "maximum": 1.0},
            "reasoning": {"type": "string", "description": "One sentence on the stroke-type call."},
        },
        "required": ["stroke_type", "phases", "confidence", "reasoning"],
    },
}
