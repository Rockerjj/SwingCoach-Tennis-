from pydantic import BaseModel, Field, ConfigDict, field_validator
from typing import Optional, Literal, Any
from datetime import datetime


def _coerce_none_to_empty_list(v: Any) -> Any:
    """Treat null/missing as empty list. LLM outputs frequently omit or null
    optional list fields even when our schema declares a default. Without this,
    Pydantic v2 strict mode rejects the entire response over a single null."""
    return [] if v is None else v


# --- Request Models ---

class JointData(BaseModel):
    name: str
    x: float
    y: float
    confidence: float


class FramePoseData(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    frame_index: int = Field(alias="frameIndex")
    timestamp: float
    joints: list[JointData]
    confidence: float


class MeasuredAngleData(BaseModel):
    value: float
    label: str
    visible: bool


class DetectedPhaseData(BaseModel):
    timestamp: float
    angles: dict[str, MeasuredAngleData] = {}


class DetectedStrokeData(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    type: str
    contact_timestamp: float = Field(alias="contactTimestamp", default=0.0)
    phases: dict[str, DetectedPhaseData] = {}


class SessionPosePayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)
    session_id: str = ""
    duration_seconds: int = 0
    fps: int = 30
    frames: list[FramePoseData] = []
    key_frame_timestamps: list[float]
    skill_level: str = "beginner"
    handedness: str = "right"
    detected_strokes: list[DetectedStrokeData] = []


class UserProfile(BaseModel):
    display_name: str = ""
    skill_level: str = "beginner"


# --- Response Models ---

ZoneStatus = Literal["in_zone", "warning", "out_of_zone"]


class MechanicDetail(BaseModel):
    score: int = Field(ge=1, le=10)
    note: str
    why_score: Optional[str] = None
    improve_cue: Optional[str] = None
    drill: Optional[str] = None
    sources: list[str] = []

    @field_validator("sources", mode="before")
    @classmethod
    def _sources_none_ok(cls, v):
        return _coerce_none_to_empty_list(v)


class StrokeMechanics(BaseModel):
    backswing: Optional[MechanicDetail] = None
    contact_point: Optional[MechanicDetail] = None
    follow_through: Optional[MechanicDetail] = None
    stance: Optional[MechanicDetail] = None
    toss: Optional[MechanicDetail] = None


# --- Swing Path Overlay ---

class PathAnnotation(BaseModel):
    label: str
    position: list[float] = Field(min_length=2, max_length=2)
    status: ZoneStatus = "in_zone"


class OverlayInstructions(BaseModel):
    angles_to_highlight: list[str] = []
    trajectory_line: bool = False
    comparison_ghost: bool = False
    swing_path_points: Optional[list[list[float]]] = None
    swing_plane_angle: Optional[float] = None
    path_annotations: Optional[list[PathAnnotation]] = None


# --- 7-Phase Swing Breakdown ---

class PhaseDetail(BaseModel):
    score: int = Field(ge=1, le=10)
    status: ZoneStatus = "in_zone"
    note: str
    timestamp: float
    key_angles: list[str] = []
    improve_cue: Optional[str] = None
    drill: Optional[str] = None


class PhaseBreakdown(BaseModel):
    ready_position: Optional[PhaseDetail] = None
    unit_turn: Optional[PhaseDetail] = None
    backswing: Optional[PhaseDetail] = None
    forward_swing: Optional[PhaseDetail] = None
    contact_point: Optional[PhaseDetail] = None
    follow_through: Optional[PhaseDetail] = None
    recovery: Optional[PhaseDetail] = None


# --- Analysis Report Card Categories ---

class SubCheck(BaseModel):
    checkpoint: str
    result: str
    status: ZoneStatus = "in_zone"


class AnalysisCategory(BaseModel):
    name: str
    description: str
    status: ZoneStatus = "in_zone"
    subchecks: list[SubCheck] = []
    thumbnail_phase: Optional[str] = None


# --- Pro Comparison ---

class AlignmentScore(BaseModel):
    body_group: str
    percentage: int = Field(ge=0, le=100)
    status: ZoneStatus = "in_zone"


class WindowBadge(BaseModel):
    label: str
    status: ZoneStatus = "in_zone"
    phase: str = ""


class ProComparisonResult(BaseModel):
    pro_name: str
    stroke_type: str
    alignment_scores: list[AlignmentScore] = []
    window_badges: list[WindowBadge] = []


# --- Stroke Result (extended) ---

class StrokeResult(BaseModel):
    type: str
    timestamp: float
    grade: str
    # mechanics and overlay_instructions both default to empty. Real providers
    # inconsistently include them. For the eval we care about the coaching
    # content (grading_rationale, phase_breakdown, analysis_categories).
    mechanics: StrokeMechanics = Field(default_factory=StrokeMechanics)
    overlay_instructions: OverlayInstructions = Field(default_factory=OverlayInstructions)
    grading_rationale: Optional[str] = None
    next_reps_plan: Optional[str] = None
    verified_sources: list[str] = []
    phase_breakdown: Optional[PhaseBreakdown] = None
    analysis_categories: Optional[list[AnalysisCategory]] = None

    @field_validator("verified_sources", mode="before")
    @classmethod
    def _verified_sources_none_ok(cls, v):
        return _coerce_none_to_empty_list(v)

    @field_validator("mechanics", "overlay_instructions", mode="before")
    @classmethod
    def _nested_none_ok(cls, v):
        return {} if v is None else v


class AnalysisResponse(BaseModel):
    session_grade: str
    strokes_detected: list[StrokeResult] = []
    tactical_notes: list[str] = []
    top_priority: str = ""
    # Empty/incomplete sessions legitimately have no overall score; LLMs
    # return null in those cases. Treat as 0.0 rather than rejecting the
    # entire response.
    overall_mechanics_score: float = 0.0
    session_summary: str = ""

    @field_validator(
        "strokes_detected", "tactical_notes", mode="before"
    )
    @classmethod
    def _list_none_ok(cls, v):
        return _coerce_none_to_empty_list(v)

    @field_validator("overall_mechanics_score", mode="before")
    @classmethod
    def _score_none_ok(cls, v):
        return 0.0 if v is None else v

    @field_validator("top_priority", "session_summary", mode="before")
    @classmethod
    def _str_none_ok(cls, v):
        return "" if v is None else v


class ProgressResponse(BaseModel):
    overall_score: float
    forehand_score: float
    backhand_score: float
    serve_score: float
    volley_score: float
    trend: str
    weekly_focus: str
    sessions_this_week: int
    sessions_this_month: int
    history: list[dict]


class SessionSummaryResponse(BaseModel):
    id: str
    recorded_at: str
    duration_seconds: int
    overall_grade: Optional[str]
    status: str
