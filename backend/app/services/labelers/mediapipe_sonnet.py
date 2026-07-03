"""Labeler H: MediaPipe joint trajectories + Claude Sonnet 4.6 vision.

Same architecture as `mediapipe_claude.py` but uses Sonnet 4.6 instead of Opus 4.7.
Sonnet is ~5× cheaper than Opus; this labeler exists to test whether we can keep
the Claude+trajectory accuracy while landing under $0.05/stroke.
"""
from __future__ import annotations

import logging

from app.config import get_settings

from . import register
from .mediapipe_claude import MediaPipeClaudeLabeler

logger = logging.getLogger(__name__)


class MediaPipeSonnetLabeler(MediaPipeClaudeLabeler):
    name = "mediapipe_sonnet"

    def __init__(self) -> None:
        super().__init__()
        settings = get_settings()
        self.model = settings.anthropic_sonnet_model


try:
    register(MediaPipeSonnetLabeler())
except Exception as e:
    logger.warning(f"MediaPipe-Sonnet labeler unavailable: {e}")
