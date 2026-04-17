"""Generate a blind score sheet from a completed eval run.

Usage (from the backend/ directory):

    python -m scripts.build_score_sheet <run_id> \\
        [--out-root test-data/eval-runs] \\
        [--seed 42]

Reads each session directory under <out-root>/<run-id>/, randomizes the
provider order with a per-session shuffle, and writes:

    <out-root>/<run-id>/blind/<session_id>/output_A.json ... output_D.json
    <out-root>/<run-id>/blind/key.json
    <out-root>/<run-id>/score_sheet.csv

DO NOT open key.json until you have finished scoring every output.
The score_sheet.csv has columns for the 6-axis rubric ready to fill in.
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import sys
import string
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


PROVIDER_FILES = ["gemini.json", "opus.json", "sonnet.json", "openai.json"]

RUBRIC_COLUMNS = [
    "session_id",
    "blind_label",
    "coaching_specificity",       # 1-5
    "biomechanical_accuracy",     # 1-5
    "ground_truth_coverage",      # integer count
    "hallucinated_sources",       # integer count
    "prompt_rule_violations",     # integer count
    "json_valid",                 # 0 or 1
    "notes",
]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate blind score sheet for an eval run")
    p.add_argument("run_id", help="Run id (subdirectory under --out-root)")
    p.add_argument("--out-root", type=Path, default=Path("test-data/eval-runs"))
    p.add_argument("--seed", type=int, default=42, help="RNG seed for reproducible shuffles")
    return p.parse_args()


def main() -> None:
    args = parse_args()
    run_root: Path = args.out_root / args.run_id
    if not run_root.is_dir():
        raise SystemExit(f"Run directory not found: {run_root}")

    blind_root = run_root / "blind"
    blind_root.mkdir(exist_ok=True)

    rng = random.Random(args.seed)

    key: dict[str, dict[str, str]] = {}  # session_id -> {label: provider}
    rows: list[dict] = []

    session_dirs = sorted(p for p in run_root.iterdir() if p.is_dir() and p.name != "blind")
    if not session_dirs:
        raise SystemExit(f"No session directories found in {run_root}")

    for sd in session_dirs:
        session_id = sd.name
        # Collect available outputs
        available: list[tuple[str, Path]] = []
        for fname in PROVIDER_FILES:
            fpath = sd / fname
            if fpath.is_file():
                available.append((fname.replace(".json", ""), fpath))
        if not available:
            print(f"  SKIP {session_id}: no provider outputs found")
            continue

        # Shuffle the order so labels A..N don't correlate with provider name
        rng.shuffle(available)

        labels = list(string.ascii_uppercase[: len(available)])
        session_key = {}
        out_session = blind_root / session_id
        out_session.mkdir(exist_ok=True)

        for label, (provider, src) in zip(labels, available):
            payload = json.loads(src.read_text())
            # Strip any obvious provider-identifying meta from the file we hand
            # the scorer, while keeping the actual analysis content intact.
            if isinstance(payload, dict) and "meta" in payload:
                payload = {**payload, "meta": {"latency_ms": payload["meta"].get("latency_ms")}}
            (out_session / f"output_{label}.json").write_text(json.dumps(payload, indent=2))
            session_key[label] = provider
            rows.append({
                "session_id": session_id,
                "blind_label": label,
                "coaching_specificity": "",
                "biomechanical_accuracy": "",
                "ground_truth_coverage": "",
                "hallucinated_sources": "",
                "prompt_rule_violations": "",
                "json_valid": "",
                "notes": "",
            })

        key[session_id] = session_key

    (blind_root / "key.json").write_text(json.dumps(key, indent=2))

    csv_path = run_root / "score_sheet.csv"
    with csv_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=RUBRIC_COLUMNS)
        w.writeheader()
        for r in rows:
            w.writerow(r)

    print(f"Blind outputs:  {blind_root}")
    print(f"Score sheet:    {csv_path}")
    print(f"Reveal key:     {blind_root / 'key.json'} (DO NOT OPEN until scoring is done)")
    print()
    print("Rubric:")
    print("  coaching_specificity (1-5):    1=generic, 5=specific/visual/actionable")
    print("  biomechanical_accuracy (1-5):  1=wrong/bad advice, 5=matches reference ranges")
    print("  ground_truth_coverage (int):   how many bullets from ground_truth.md were surfaced")
    print("  hallucinated_sources (int):    bogus entries in verified_sources")
    print("  prompt_rule_violations (int):  raw degrees in prose, fabricated NOT_VISIBLE angles, missing phases")
    print("  json_valid (0/1):              did it parse against AnalysisResponse")


if __name__ == "__main__":
    main()
