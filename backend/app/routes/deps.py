from typing import Optional
import logging

from fastapi import Header, HTTPException
from supabase import create_client, Client

from app.config import get_settings

_supabase_client: Optional[Client] = None
logger = logging.getLogger(__name__)


def get_supabase() -> Client:
    global _supabase_client
    if _supabase_client is None:
        settings = get_settings()
        try:
            _supabase_client = create_client(settings.supabase_url, settings.supabase_service_key)
        except Exception as exc:
            logger.error("Supabase client init failed, continuing without persistence: %s", exc)
            return None  # type: ignore[return-value]
    return _supabase_client


def get_current_user_id(
    authorization: str = Header(
        default="Bearer dev-token",
        description="Bearer token from Apple Sign In",
    ),
) -> str:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")

    settings = get_settings()

    token = authorization.removeprefix("Bearer ").strip()
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")

    # In debug mode, accept any token and return a dev user ID
    if settings.debug:
        logger.warning("DEBUG AUTH: Bypassing token verification")
        return "dev-user-001"

    # Try to decode as a Supabase JWT
    try:
        from jose import jwt
        payload = jwt.decode(
            token,
            settings.supabase_key,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        return user_id
    except Exception as e:
        logger.warning(f"JWT decode failed: {e}")

    # Fallback: treat the token itself as a user identifier (for guest/dev tokens)
    # This allows the app to work during early development without full Supabase auth
    if len(token) > 8:
        logger.info(f"Using token-based user ID (first 8 chars): {token[:8]}...")
        return f"guest-{token[:32]}"

    raise HTTPException(status_code=401, detail="Token verification failed")
