"""Create a ground-truth CSV template from captured analysis payloads.

Usage from backend/:

    python -m scripts.build_ground_truth_template \
        --sessions-root test-data/sessions \
        --out test-data/ground-truth/sessions.csv

The output includes one row per captured candidate stroke. Fill in the
`correct_*` columns, then run `python -m scripts.eval_labelers`.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

PHASE_NAMES = (
    "ready_position",
    "unit_turn",
    "backswing",
    "forward_swing",
    "contact_point",
    "follow_through",
    "recovery",
)


def _clip_name_for_index(session_dir: Path, idx: int) -> str:
    clips = sorted((session_dir / "stroke_clips").glob("stroke_clip_*.mp4"))
    if idx < len(clips):
        return clips[idx].name
    return ""


def build_rows(sessions_root: Path) -> list[dict]:
    rows: list[dict] = []
    for session_dir in sorted(p for p in sessions_root.iterdir() if p.is_dir()):
        pose_path = session_dir / "pose_data.json"
        if not pose_path.exists():
            continue
        data = json.loads(pose_path.read_text())
        for idx, stroke in enumerate(data.get("detected_strokes", [])):
            phases = stroke.get("phases", {}) or {}
            row = {
                "session_id": session_dir.name,
                "stroke_idx": idx,
                "clip_file": _clip_name_for_index(session_dir, idx),
                "ios_stroke_type": stroke.get("type", ""),
                "ios_contact_time": stroke.get("contactTimestamp") or stroke.get("contact_timestamp") or "",
                "correct_stroke_type": "",
                "camera_angle": "",
                "visibility_quality": "",
                "failure_notes": "",
            }
            for phase in PHASE_NAMES:
                phase_data = phases.get(phase) or {}
                row[f"ios_{phase}_time"] = phase_data.get("timestamp", "")
                row[f"correct_{phase}_time"] = ""
            rows.append(row)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sessions-root", type=Path, default=Path("test-data/sessions"))
    parser.add_argument("--out", type=Path, default=Path("test-data/ground-truth/sessions.csv"))
    args = parser.parse_args()

    rows = build_rows(args.sessions_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "session_id",
        "stroke_idx",
        "clip_file",
        "ios_stroke_type",
        "ios_contact_time",
        "correct_stroke_type",
        "camera_angle",
        "visibility_quality",
        "failure_notes",
    ]
    for phase in PHASE_NAMES:
        fieldnames.extend([f"ios_{phase}_time", f"correct_{phase}_time"])

    with open(args.out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {args.out}")


if __name__ == "__main__":
    main()
