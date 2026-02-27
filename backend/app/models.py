from pydantic import BaseModel, Field, ConfigDict
from typing import Optional, Literal
from datetime import datetime


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
    type: str
    contact_timestamp: float
    phases: dict[str, DetectedPhaseData] = {}


class SessionPosePayload(BaseModel):
    session_id: str
    duration_seconds: int
    fps: int
    frames: list[FramePoseData]
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
    mechanics: StrokeMechanics
    overlay_instructions: OverlayInstructions
    grading_rationale: Optional[str] = None
    next_reps_plan: Optional[str] = None
    verified_sources: list[str] = []
    phase_breakdown: Optional[PhaseBreakdown] = None
    analysis_categories: Optional[list[AnalysisCategory]] = None


class AnalysisResponse(BaseModel):
    session_grade: str
    strokes_detected: list[StrokeResult]
    tactical_notes: list[str]
    top_priority: str
    overall_mechanics_score: float
    session_summary: str


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
