from fastapi import APIRouter, Depends
from supabase import Client

from app.models import UserProfile
from app.routes.deps import get_supabase, get_current_user_id

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/profile")
def create_or_update_profile(
    profile: UserProfile,
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    data = {
        "id": user_id,
        "display_name": profile.display_name,
        "skill_level": profile.skill_level,
    }
    result = supabase.table("user_profiles").upsert(data).execute()
    return result.data[0] if result.data else data


@router.get("/profile")
def get_profile(
    user_id: str = Depends(get_current_user_id),
    supabase: Client = Depends(get_supabase),
):
    result = (
        supabase.table("user_profiles")
        .select("*")
        .eq("id", user_id)
        .single()
        .execute()
    )
    return result.data
