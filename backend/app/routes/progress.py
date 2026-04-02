from fastapi import APIRouter, Depends
from supabase import Client

from app.services.progress_calculator import ProgressCalculator
from app.routes.deps import get_supabase, get_current_user_id

router = APIRouter(prefix="/progress", tags=["progress"])


@router.get("")
def get_progress(
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    calculator = ProgressCalculator(supabase)
    return calculator.get_progress(user_id)
