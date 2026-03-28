from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "Tennique API"
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

    def is_debug_auth_allowed(self) -> bool:
        """Debug auth bypass requires BOTH debug=True AND explicit ALLOW_DEBUG_AUTH=true."""
        import os
        return self.debug and os.getenv("ALLOW_DEBUG_AUTH", "").lower() == "true"


@lru_cache()
def get_settings() -> Settings:
    settings = Settings()
    # Safety: warn loudly if debug is on
    if settings.debug:
        import logging
        logging.getLogger(__name__).warning(
            "⚠️  DEBUG MODE IS ON — ensure this is not a production deployment"
        )
    return settings
