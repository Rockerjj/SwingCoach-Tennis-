import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routes import sessions, progress, users, feedback

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    docs_url="/docs" if settings.debug else None,
    redoc_url="/redoc" if settings.debug else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sessions.router, prefix="/api/v1")
app.include_router(progress.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": settings.app_name}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=settings.debug)
