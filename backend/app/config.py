from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "TennisIQ API"
    debug: bool = False

    # OpenAI
    openai_api_key: str = ""
    openai_model: str = "gpt-5.4"

    # Supabase
    supabase_url: str = ""
    supabase_key: str = ""
    supabase_service_key: str = ""

    # Auth
    apple_team_id: str = ""
    apple_bundle_id: str = "com.tennique.app"

    # Rate limits
    max_video_duration_seconds: int = 1800
    max_key_frames: int = 20

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
