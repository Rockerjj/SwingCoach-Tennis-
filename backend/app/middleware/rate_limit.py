"""Simple in-memory rate limiter for the /analyze endpoint.

Uses a per-user sliding window. In production, swap for Redis-backed.
"""

import time
import logging
from collections import defaultdict
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)

# Config: max requests per window
MAX_REQUESTS = 10
WINDOW_SECONDS = 3600  # 1 hour


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Rate-limit POST /api/v1/sessions/analyze per user (by Authorization header)."""

    def __init__(self, app, max_requests: int = MAX_REQUESTS, window_seconds: int = WINDOW_SECONDS):
        super().__init__(app)
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        # user_key -> list of timestamps
        self._requests: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        # Only rate-limit the analyze endpoint
        if request.method == "POST" and request.url.path.rstrip("/").endswith("/sessions/analyze"):
            user_key = self._get_user_key(request)
            now = time.monotonic()

            # Prune old entries
            window_start = now - self.window_seconds
            self._requests[user_key] = [
                t for t in self._requests[user_key] if t > window_start
            ]

            if len(self._requests[user_key]) >= self.max_requests:
                retry_after = int(self._requests[user_key][0] + self.window_seconds - now) + 1
                logger.warning(f"Rate limit exceeded for {user_key}: {len(self._requests[user_key])} requests in window")
                raise HTTPException(
                    status_code=429,
                    detail=f"Rate limit exceeded. Try again in {retry_after} seconds.",
                    headers={"Retry-After": str(retry_after)},
                )

            self._requests[user_key].append(now)

        response = await call_next(request)
        return response

    @staticmethod
    def _get_user_key(request: Request) -> str:
        """Extract a rate-limit key from the request — prefer auth token, fall back to IP."""
        auth = request.headers.get("authorization", "")
        if auth.startswith("Bearer ") and len(auth) > 20:
            # Use first 32 chars of token as key (enough to distinguish users, not store full token)
            return f"token:{auth[7:39]}"
        # Fall back to client IP
        client = request.client
        return f"ip:{client.host if client else 'unknown'}"
