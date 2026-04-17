"""
Test the full Tennique analysis pipeline with a real video.
Simulates what the iOS app does: extract key frames + send to backend GPT-5.4.
"""
import asyncio
import json
import sys
import subprocess
import os
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from dotenv import load_dotenv
load_dotenv()

from app.services.llm_coaching import LLMCoachingService
from app.models import (
    SessionPosePayload, DetectedStrokeData, DetectedPhaseData, MeasuredAngleData
)

# Re-export so callers can `from test_pipeline import load_captured_session`.
try:
    from scripts.session_loader import load_captured_session  # noqa: F401
except ImportError:
    # scripts/ may not be on the import path in some run contexts; that's fine,
    # the mock build_mock_payload below still works.
    load_captured_session = None  # type: ignore[assignment]


def extract_key_frames(video_path: str, fps: float = 2, max_frames: int = 8) -> list[bytes]:
    import tempfile
    tmpdir = tempfile.mkdtemp()
    subprocess.run([
        "ffmpeg", "-i", video_path, "-vf", f"fps={fps}",
        "-q:v", "2", "-frames:v", str(max_frames),
        f"{tmpdir}/frame_%03d.jpg", "-y"
    ], capture_output=True)
    frames = [f.read_bytes() for f in sorted(Path(tmpdir).glob("frame_*.jpg"))]
    print(f"  Extracted {len(frames)} key frames")
    return frames


def ang(value, name):
    return MeasuredAngleData(value=value, label=f"{name}: {int(value)}°", visible=True)


def build_mock_payload(duration: float = 27.0) -> SessionPosePayload:
    stroke = DetectedStrokeData(
        type="forehand",
        contact_timestamp=12.0,
        phases={
            "ready_position": DetectedPhaseData(timestamp=10.0, angles={
                "elbow_angle": ang(145, "Elbow"), "knee_angle": ang(155, "Knee"),
                "hip_angle": ang(170, "Hip"), "shoulder_rotation": ang(15, "Shoulder rotation"),
                "arm_extension": ang(60, "Arm extension"),
            }),
            "unit_turn": DetectedPhaseData(timestamp=10.5, angles={
                "elbow_angle": ang(130, "Elbow"), "knee_angle": ang(145, "Knee"),
                "hip_angle": ang(160, "Hip"), "shoulder_rotation": ang(45, "Shoulder rotation"),
                "arm_extension": ang(70, "Arm extension"),
            }),
            "backswing": DetectedPhaseData(timestamp=11.0, angles={
                "elbow_angle": ang(100, "Elbow"), "knee_angle": ang(140, "Knee"),
                "hip_angle": ang(150, "Hip"), "shoulder_rotation": ang(65, "Shoulder rotation"),
                "arm_extension": ang(90, "Arm extension"),
            }),
            "forward_swing": DetectedPhaseData(timestamp=11.5, angles={
                "elbow_angle": ang(120, "Elbow"), "knee_angle": ang(135, "Knee"),
                "hip_angle": ang(155, "Hip"), "shoulder_rotation": ang(40, "Shoulder rotation"),
                "arm_extension": ang(120, "Arm extension"),
            }),
            "contact_point": DetectedPhaseData(timestamp=12.0, angles={
                "elbow_angle": ang(155, "Elbow"), "knee_angle": ang(140, "Knee"),
                "hip_angle": ang(165, "Hip"), "shoulder_rotation": ang(20, "Shoulder rotation"),
                "arm_extension": ang(150, "Arm extension"),
            }),
            "follow_through": DetectedPhaseData(timestamp=12.5, angles={
                "elbow_angle": ang(90, "Elbow"), "knee_angle": ang(145, "Knee"),
                "hip_angle": ang(170, "Hip"), "shoulder_rotation": ang(10, "Shoulder rotation"),
                "arm_extension": ang(100, "Arm extension"),
            }),
            "recovery": DetectedPhaseData(timestamp=13.0, angles={
                "elbow_angle": ang(140, "Elbow"), "knee_angle": ang(155, "Knee"),
                "hip_angle": ang(175, "Hip"), "shoulder_rotation": ang(5, "Shoulder rotation"),
                "arm_extension": ang(50, "Arm extension"),
            }),
        }
    )
    return SessionPosePayload(
        session_id="test-session-001",
        skill_level="intermediate",
        handedness="right",
        duration_seconds=int(duration),
        fps=30,
        frames=[],
        key_frame_timestamps=[10.0, 11.0, 12.0, 13.0],
        detected_strokes=[stroke],
    )


async def main():
    video_path = str(Path(__file__).parent.parent / "test-data" / "sample-swing.mp4")

    print("=" * 60)
    print("TENNIQUE PIPELINE TEST — GPT-5.4 + Vision")
    print("=" * 60)
    print(f"Video: {video_path}")
    print(f"Model: {os.getenv('OPENAI_MODEL', 'gpt-5.4')}")
    print()

    print("[1/3] Extracting key frames...")
    key_frames = extract_key_frames(video_path, fps=2, max_frames=8)

    print("[2/3] Building pose payload (mock)...")
    payload = build_mock_payload(duration=27.0)
    print(f"  Strokes: {len(payload.detected_strokes)} ({payload.detected_strokes[0].type})")

    print(f"[3/3] Sending to GPT-5.4 with {len(key_frames)} images (detail=high)...")
    print("  This may take 30-60 seconds...\n")

    coaching = LLMCoachingService()
    result = await coaching.analyze_session(payload, key_frames)

    print("=" * 60)
    print("ANALYSIS RESULTS")
    print("=" * 60)
    print(f"Session Grade: {result.session_grade}")
    print(f"Top Priority: {result.top_priority}")
    print()

    if result.tactical_notes:
        print("Tactical Notes:")
        if isinstance(result.tactical_notes, list):
            for note in result.tactical_notes:
                print(f"  • {note}")
        else:
            print(f"  {result.tactical_notes}")
        print()

    for i, stroke in enumerate(result.strokes_detected):
        print(f"--- Stroke {i+1}: {stroke.type.upper()} ---")
        print(f"  Grade: {stroke.grade}")
        print(f"  Timestamp: {stroke.timestamp}s")
        if hasattr(stroke, 'mechanics') and stroke.mechanics:
            print("  Mechanics:")
            for k, v in stroke.mechanics.model_dump().items():
                if v:
                    print(f"    {k}: {v}")
        if hasattr(stroke, 'overlay_instructions') and stroke.overlay_instructions:
            print("  Overlay:")
            for k, v in stroke.overlay_instructions.model_dump().items():
                if v:
                    print(f"    {k}: {v}")
        print()

    output_path = str(Path(__file__).parent.parent / "test-data" / "analysis-result.json")
    with open(output_path, "w") as f:
        json.dump(result.model_dump(), f, indent=2, default=str)
    print(f"Full JSON saved to: {output_path}")


if __name__ == "__main__":
    asyncio.run(main())
