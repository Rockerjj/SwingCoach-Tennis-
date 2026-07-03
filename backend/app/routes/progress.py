from typing import Optional

from fastapi import APIRouter, Depends
from supabase import Client

from app.services.progress_calculator import ProgressCalculator
from app.routes.deps import get_supabase, get_current_user_id

router = APIRouter(prefix="/progress", tags=["progress"])


# Empty default returned when Supabase isn't configured (eval/dev mode).
# Keeps the iOS app from showing an error after every successful analysis
# just because we don't have persistence wired up locally.
_EMPTY_PROGRESS = {
    "overall_score": 0.0,
    "forehand_score": 0.0,
    "backhand_score": 0.0,
    "serve_score": 0.0,
    "volley_score": 0.0,
    "trend": "stable",
    "weekly_focus": "",
    "sessions_this_week": 0,
    "sessions_this_month": 0,
    "history": [],
}


@router.get("")
def get_progress(
    user_id: str = Depends(get_current_user_id),
    supabase: Optional[Client] = Depends(get_supabase),
):
    if supabase is None:
        return _EMPTY_PROGRESS
    calculator = ProgressCalculator(supabase)
    return calculator.get_progress(user_id)
