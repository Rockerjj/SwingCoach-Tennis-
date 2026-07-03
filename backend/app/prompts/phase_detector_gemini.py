"""Prompt + response schema for Gemini 2.5 Pro phase-detection bake-off labeler.

Scope: single stroke clip in -> JSON out (stroke_type + 7 phase timestamps).
Nothing here touches production coaching — this is for the offline eval harness.
"""
from __future__ import annotations

PHASE_DETECTOR_SYSTEM = """You are an expert tennis biomechanics analyst watching a short clip of a single stroke.
Your ONLY job is to label:
  1. The stroke type.
  2. The exact clip-relative timestamp (in seconds) of each of the 7 swing phases.

You are NOT coaching. Do not comment on quality, do not suggest drills, do not grade anything.
Do not trust the app's initial stroke guess. Use the video and measured joint trajectory as the evidence source.
Output must be strict JSON matching the requested schema. Nothing else.
"""


PHASE_DETECTOR_USER = """## Clip context
- iOS on-device heuristic guessed this was a `{ios_type}` stroke. This may be wrong. Re-decide from the video.
- The clip is {clip_duration:.2f}s long. Contact appears to happen near the middle.

## Stroke types
- `forehand`: dominant-hand side swing, racket comes from behind the body and crosses forward.
- `backhand`: non-dominant side. Either one-handed (single arm extended back) or two-handed (both hands on grip).
- `serve`: overhead motion, player starts stationary, tosses ball with non-dominant arm.
- `volley`: short compact punch, minimal backswing, usually at or inside the service line.
- `unknown`: clip is ambiguous, occluded, or not actually a stroke.

## Seven phases (report each as clip-relative seconds)
1. `ready_position` — player is balanced, facing the net, waiting. Usually the very start of the clip.
2. `unit_turn` — shoulders + hips begin rotating toward the side the ball is on. Racket starts moving back.
3. `backswing` — racket is at the peak of its take-back. Loaded, about to swing forward.
4. `forward_swing` — racket is in motion toward the ball, before contact.
5. `contact_point` — racket meets ball. This is the most visually identifiable moment.
6. `follow_through` — racket has traveled past contact, decelerating, usually finishing across the body or over the shoulder.
7. `recovery` — player returns toward ready position / neutral stance for the next shot.

Constraints:
- All 7 timestamps MUST be strictly increasing: ready_position < unit_turn < backswing < forward_swing < contact_point < follow_through < recovery.
- If a phase is not clearly visible (e.g. clip ends before recovery), estimate the best timestamp anyway — never return null.
- All timestamps must be within [0, {clip_duration:.2f}].

## Output schema (return this JSON exactly — no prose, no markdown)
{{
  "stroke_type": "forehand" | "backhand" | "serve" | "volley" | "unknown",
  "phases": {{
    "ready_position": <float seconds>,
    "unit_turn": <float>,
    "backswing": <float>,
    "forward_swing": <float>,
    "contact_point": <float>,
    "follow_through": <float>,
    "recovery": <float>
  }},
  "confidence": <float 0.0-1.0>,
  "reasoning": "<one sentence explaining the stroke-type call>"
}}
"""


def build_user_prompt(ios_type: str, clip_duration: float) -> str:
    return PHASE_DETECTOR_USER.format(
        ios_type=ios_type or "unknown",
        clip_duration=clip_duration,
    )
