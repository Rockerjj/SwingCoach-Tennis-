from pydantic import BaseModel, Field, ConfigDict
from typing import Optional
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


class SessionPosePayload(BaseModel):
    session_id: str
    duration_seconds: int
    fps: int
    frames: list[FramePoseData]
    key_frame_timestamps: list[float]
    skill_level: str = "beginner"


class UserProfile(BaseModel):
    display_name: str = ""
    skill_level: str = "beginner"


# --- Response Models ---

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


class OverlayInstructions(BaseModel):
    angles_to_highlight: list[str] = []
    trajectory_line: bool = False
    comparison_ghost: bool = False


class StrokeResult(BaseModel):
    type: str
    timestamp: float
    grade: str
    mechanics: StrokeMechanics
    overlay_instructions: OverlayInstructions
    grading_rationale: Optional[str] = None
    next_reps_plan: Optional[str] = None
    verified_sources: list[str] = []


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
