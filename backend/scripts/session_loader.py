"""Load a captured analyze payload from disk.

Captured layout (written by routes/sessions.py when DEBUG_CAPTURE_PAYLOADS=true):

  test-data/sessions/<session_id>/
    metadata.json
    pose_data.json
    key_frames/key_frame_000.jpg ...
    stroke_clips/stroke_clip_000_<ts>.mp4 ...
"""
from __future__ import annotations

import json
import re
from pathlib import Path

from app.models import SessionPosePayload


_CLIP_TS_RE = re.compile(r"stroke_clip_\d+_([\d.]+)\.mp4$")


def load_captured_session(
    session_dir: str | Path,
) -> tuple[SessionPosePayload, list[bytes], list[tuple[float, bytes]]]:
    """Read pose_data, keyframes, and stroke clips from a captured session.

    Returns: (pose_payload, key_frame_images, video_clips)
    """
    base = Path(session_dir)
    if not base.is_dir():
        raise FileNotFoundError(f"Session directory not found: {base}")

    pose_path = base / "pose_data.json"
    if not pose_path.is_file():
        raise FileNotFoundError(f"Missing pose_data.json in {base}")
    pose_payload = SessionPosePayload(**json.loads(pose_path.read_text()))

    key_frame_images: list[bytes] = []
    frames_dir = base / "key_frames"
    if frames_dir.is_dir():
        for p in sorted(frames_dir.glob("key_frame_*.jpg")):
            key_frame_images.append(p.read_bytes())

    video_clips: list[tuple[float, bytes]] = []
    clips_dir = base / "stroke_clips"
    if clips_dir.is_dir():
        for p in sorted(clips_dir.glob("stroke_clip_*.mp4")):
            m = _CLIP_TS_RE.search(p.name)
            ts = float(m.group(1)) if m else 0.0
            video_clips.append((ts, p.read_bytes()))

    return pose_payload, key_frame_images, video_clips
