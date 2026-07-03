"""Pluggable stroke + phase labelers for the detection bake-off.

Each labeler consumes a stroke video clip (plus optionally the iOS pose JSON)
and returns a normalized LabelerResult so the eval harness can score every
candidate against the same ground-truth CSV.

Labelers are NOT wired into the production /sessions/analyze route. They exist
purely to answer: which model (if any) does stroke-type + phase-timestamp
detection better than the iOS velocity-threshold heuristic?
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal, Protocol

StrokeType = Literal["forehand", "backhand", "serve", "volley", "unknown"]

PHASE_NAMES = (
    "ready_position",
    "unit_turn",
    "backswing",
    "forward_swing",
    "contact_point",
    "follow_through",
    "recovery",
)


@dataclass
class LabelerInput:
    """Everything a labeler is allowed to see about one stroke."""
    session_id: str
    stroke_idx: int
    clip_bytes: bytes
    clip_timestamp: float  # seconds into the full session where this clip starts
    ios_stroke_type: str   # what the on-device heuristic said (for baseline + context)
    ios_phases: dict[str, float]  # iOS-labeled phase timestamps (absolute session time)
    clip_duration: float = 0.0
    handedness: str = "right"


@dataclass
class LabelerResult:
    stroke_type: StrokeType
    phases: dict[str, float]  # phase_name -> absolute session timestamp (seconds)
    latency_ms: int = 0
    input_tokens: int | None = None
    output_tokens: int | None = None
    cost_cents_estimate: float | None = None
    confidence: float | None = None
    raw_response: str | None = None  # for debugging
    error: str | None = None

    def ordering_valid(self) -> bool:
        """True iff all 7 phase timestamps are strictly increasing in PHASE_NAMES order."""
        ordered = [self.phases.get(p) for p in PHASE_NAMES]
        if any(t is None for t in ordered):
            return False
        return all(ordered[i] < ordered[i + 1] for i in range(len(ordered) - 1))


class Labeler(Protocol):
    """Implemented by every candidate (iOS heuristic, Gemini, Claude, on-device)."""
    name: str

    async def label(self, stroke: LabelerInput) -> LabelerResult: ...


# Registry populated by each module on import. Kept lazy so harness can opt in.
_REGISTRY: dict[str, Labeler] = {}


def register(labeler: Labeler) -> None:
    _REGISTRY[labeler.name] = labeler


def get(name: str) -> Labeler:
    if name not in _REGISTRY:
        # Lazy import so missing optional deps only bite the labeler that needs them.
        if name == "ios":
            from . import ios_heuristic  # noqa: F401
        elif name == "gemini":
            from . import gemini_video  # noqa: F401
        elif name == "claude":
            from . import claude_frames  # noqa: F401
        elif name == "mediapipe_heuristic":
            from . import mediapipe_heuristic  # noqa: F401
        elif name == "mediapipe_claude":
            from . import mediapipe_claude  # noqa: F401
        elif name == "mediapipe_gemini":
            from . import mediapipe_gemini  # noqa: F401
        elif name == "mediapipe_sonnet":
            from . import mediapipe_sonnet  # noqa: F401
    if name not in _REGISTRY:
        raise KeyError(f"No labeler registered under {name!r}. Known: {sorted(_REGISTRY)}")
    return _REGISTRY[name]


def all_names() -> list[str]:
    # Trigger imports so the registry is populated
    for mod in ("ios_heuristic", "gemini_video", "claude_frames",
                "mediapipe_heuristic", "mediapipe_claude",
                "mediapipe_gemini", "mediapipe_sonnet"):
        try:
            __import__(f"app.services.labelers.{mod}")
        except Exception:
            pass
    return sorted(_REGISTRY)
