"""Score every labeler against hand-labeled ground truth.

Usage (from backend/):

    python -m scripts.eval_labelers \\
        [--ground-truth test-data/ground-truth/sessions.csv] \\
        [--sessions-root test-data/sessions] \\
        [--out-root test-data/eval-runs] \\
        [--labelers ios,gemini,claude]

Writes:

    <out-root>/labelers-<run_id>/labeler_comparison.csv
    <out-root>/labelers-<run_id>/summary.json
    <out-root>/labelers-<run_id>/<session_id>/<stroke_idx>_<labeler>.json

Score columns:
    - stroke_type_correct (bool)
    - phase_mae_seconds (mean absolute error across the 6 post-ready phases)
    - ordering_valid (bool)
    - latency_ms, input_tokens, output_tokens, cost_cents_estimate
"""
from __future__ import annotations

import argparse
import asyncio
import csv
import json
import logging
import statistics
import sys
import time
import uuid
from pathlib import Path

# Make `app.*` importable
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from app.services.labelers import LabelerInput, LabelerResult, all_names, get, PHASE_NAMES
from scripts.pricing import estimate_cost_cents
from scripts.session_loader import load_captured_session

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("eval_labelers")


SCORED_PHASES = PHASE_NAMES[1:]  # skip ready_position per plan


def _load_ground_truth(path: Path) -> dict[tuple[str, int], dict]:
    """Returns {(session_id, stroke_idx): {stroke_type, phase_times: {...}}}."""
    truth: dict[tuple[str, int], dict] = {}
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sid = row["session_id"].strip()
            idx = int(row["stroke_idx"])
            stype = row.get("correct_stroke_type", "").strip()
            if not stype:
                continue  # not yet labeled
            phase_times = {}
            for p in PHASE_NAMES:
                v = row.get(f"correct_{p}_time", "").strip()
                if v:
                    try:
                        phase_times[p] = float(v)
                    except ValueError:
                        pass
            truth[(sid, idx)] = {
                "stroke_type": stype,
                "phases": phase_times,
                "clip_file": row.get("clip_file", "").strip(),
            }
    return truth


def _score(result: LabelerResult, truth: dict) -> dict:
    type_correct = (result.stroke_type or "").lower() == (truth["stroke_type"] or "").lower()

    # MAE over phases that exist in BOTH ground truth and labeler output (excl. ready_position)
    errs: list[float] = []
    per_phase_err: dict[str, float] = {}
    for p in SCORED_PHASES:
        gt = truth["phases"].get(p)
        pred = result.phases.get(p)
        if gt is not None and pred is not None:
            err = abs(pred - gt)
            errs.append(err)
            per_phase_err[p] = err
    mae = statistics.mean(errs) if errs else None
    contact_gt = truth["phases"].get("contact_point")
    contact_pred = result.phases.get("contact_point")
    contact_err = (
        abs(contact_pred - contact_gt)
        if contact_gt is not None and contact_pred is not None
        else None
    )

    return {
        "stroke_type_correct": type_correct,
        "phase_mae_seconds": mae,
        "phase_mae_phases_scored": len(errs),
        "contact_point_abs_error": contact_err,
        "per_phase_abs_error": per_phase_err,
        "ordering_valid": result.ordering_valid(),
    }


def _percentile(values: list[float | int], pct: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    idx = round((len(ordered) - 1) * pct)
    return ordered[idx]


def _mean_or_none(values: list[float | int]) -> float | None:
    return statistics.mean(values) if values else None


def _summarize_rows(rows: list[dict], names: list[str]) -> dict:
    """Summarize labeler output without hiding failures.

    Accuracy, ordering, and coverage use every attempted row as the denominator.
    Errored and unknown rows are failed attempts because that is what users see.
    """
    summary: dict = {}
    full_phase_count = len(SCORED_PHASES)

    for name in names:
        rows_for_labeler = [r for r in rows if r.get("labeler") == name]
        attempted = len(rows_for_labeler)
        if not rows_for_labeler:
            summary[name] = {
                "attempted": 0,
                "error": "no attempted calls",
            }
            continue

        errored = [r for r in rows_for_labeler if r.get("error") is not None]
        unknown = [
            r for r in rows_for_labeler
            if (r.get("pred_stroke_type") or "").lower() == "unknown"
        ]
        type_correct = [
            r for r in rows_for_labeler
            if bool(r.get("stroke_type_correct"))
        ]
        full_phase_rows = [
            r for r in rows_for_labeler
            if int(r.get("phase_mae_phases_scored") or 0) >= full_phase_count
        ]
        ordering_valid = [
            r for r in rows_for_labeler
            if bool(r.get("ordering_valid"))
        ]
        maes = [
            r["phase_mae_seconds"]
            for r in rows_for_labeler
            if r.get("phase_mae_seconds") is not None
        ]
        contact_errs = [
            r["contact_point_abs_error"]
            for r in rows_for_labeler
            if r.get("contact_point_abs_error") is not None
        ]
        lats = [
            r["latency_ms"]
            for r in rows_for_labeler
            if r.get("latency_ms") is not None
        ]
        costs = [
            r["cost_cents_estimate"]
            for r in rows_for_labeler
            if r.get("cost_cents_estimate") is not None
        ]

        confusion: dict[str, dict[str, int]] = {}
        for r in rows_for_labeler:
            truth = (r.get("truth_stroke_type") or "unknown").lower()
            pred = (
                "error"
                if r.get("error") is not None
                else (r.get("pred_stroke_type") or "unknown").lower()
            )
            confusion.setdefault(truth, {})
            confusion[truth][pred] = confusion[truth].get(pred, 0) + 1

        summary[name] = {
            "attempted": attempted,
            "succeeded": attempted - len(errored),
            "unknown": len(unknown),
            "errored": len(errored),
            "overwritten": len([
                r for r in rows_for_labeler
                if r.get("pred_stroke_type") not in (None, "", "unknown")
            ]),
            "stroke_type_accuracy": round(len(type_correct) / attempted, 3),
            "phase_coverage_rate": round(len(full_phase_rows) / attempted, 3),
            "phase_mae_seconds_mean": round(_mean_or_none(maes), 3) if maes else None,
            "phase_mae_seconds_median": round(statistics.median(maes), 3) if maes else None,
            "contact_point_mae_seconds_mean": round(_mean_or_none(contact_errs), 3) if contact_errs else None,
            "contact_point_mae_seconds_median": round(statistics.median(contact_errs), 3) if contact_errs else None,
            "ordering_valid_rate": round(len(ordering_valid) / attempted, 3),
            "latency_ms_median": int(statistics.median(lats)) if lats else None,
            "latency_ms_p95": int(_percentile(lats, 0.95)) if lats else None,
            "cost_cents_mean": round(statistics.mean(costs), 4) if costs else None,
            "confusion_matrix": confusion,
        }

    return summary


def _build_input(session_dir: Path, stroke_idx: int, clip_file: str) -> LabelerInput | None:
    """Assemble a LabelerInput for a single stroke."""
    pose_path = session_dir / "pose_data.json"
    if not pose_path.exists():
        return None
    data = json.loads(pose_path.read_text())
    strokes = data.get("detected_strokes", [])
    if stroke_idx >= len(strokes):
        return None
    stroke = strokes[stroke_idx]
    ios_type = stroke.get("type", "unknown")
    phases = stroke.get("phases", {}) or {}
    ios_phases = {
        k: v.get("timestamp") if isinstance(v, dict) else v
        for k, v in phases.items()
    }
    ios_phases = {k: v for k, v in ios_phases.items() if isinstance(v, (int, float))}

    # Find clip
    clips_dir = session_dir / "stroke_clips"
    clip_path = None
    if clip_file:
        candidate = clips_dir / clip_file
        if candidate.exists():
            clip_path = candidate
    if clip_path is None:
        clip_paths = sorted(clips_dir.glob("stroke_clip_*.mp4"))
        if stroke_idx < len(clip_paths):
            clip_path = clip_paths[stroke_idx]
    if clip_path is None:
        return None

    # Clip timestamp: contact_point if we have it, else first ios phase time
    clip_ts = ios_phases.get("contact_point") or min(ios_phases.values(), default=0.0)

    return LabelerInput(
        session_id=session_dir.name,
        stroke_idx=stroke_idx,
        clip_bytes=clip_path.read_bytes(),
        clip_timestamp=float(clip_ts) - 1.5,  # clip is ~±1.5s around contact
        ios_stroke_type=ios_type,
        ios_phases=ios_phases,
    )


async def _run_one(
    labeler_name: str,
    stroke_input: LabelerInput,
    truth: dict,
    out_dir: Path,
) -> dict:
    try:
        labeler = get(labeler_name)
    except Exception as e:
        return {
            "labeler": labeler_name,
            "session_id": stroke_input.session_id,
            "stroke_idx": stroke_input.stroke_idx,
            "error": f"labeler unavailable: {e}",
        }

    try:
        result = await labeler.label(stroke_input)
    except Exception as e:
        logger.exception(f"{labeler_name} crashed on {stroke_input.session_id}#{stroke_input.stroke_idx}")
        return {
            "labeler": labeler_name,
            "session_id": stroke_input.session_id,
            "stroke_idx": stroke_input.stroke_idx,
            "error": f"{type(e).__name__}: {e}",
        }

    # Cost estimate for hosted labelers
    from app.config import get_settings
    settings = get_settings()
    model = None
    if labeler_name == "gemini":
        model = settings.gemini_model
    elif labeler_name == "claude":
        model = settings.anthropic_opus_model
    cost = None
    if model and result.input_tokens is not None and result.output_tokens is not None:
        try:
            cost = estimate_cost_cents(model, result.input_tokens, result.output_tokens)
        except Exception:
            cost = None

    scored = _score(result, truth)

    # Persist full result
    stroke_out = out_dir / stroke_input.session_id
    stroke_out.mkdir(parents=True, exist_ok=True)
    (stroke_out / f"{stroke_input.stroke_idx:02d}_{labeler_name}.json").write_text(json.dumps({
        "labeler": labeler_name,
        "result": {
            "stroke_type": result.stroke_type,
            "phases": result.phases,
            "latency_ms": result.latency_ms,
            "input_tokens": result.input_tokens,
            "output_tokens": result.output_tokens,
            "cost_cents_estimate": cost,
            "confidence": result.confidence,
            "error": result.error,
            "raw_response_preview": (result.raw_response or "")[:500],
        },
        "truth": truth,
        "score": scored,
    }, indent=2))

    return {
        "labeler": labeler_name,
        "session_id": stroke_input.session_id,
        "stroke_idx": stroke_input.stroke_idx,
        "truth_stroke_type": truth["stroke_type"],
        "pred_stroke_type": result.stroke_type,
        **scored,
        "latency_ms": result.latency_ms,
        "input_tokens": result.input_tokens,
        "output_tokens": result.output_tokens,
        "cost_cents_estimate": cost,
        "confidence": result.confidence,
        "error": result.error,
    }


async def _amain() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--ground-truth", type=Path, default=Path("test-data/ground-truth/sessions.csv"))
    p.add_argument("--sessions-root", type=Path, default=Path("test-data/sessions"))
    p.add_argument("--out-root", type=Path, default=Path("test-data/eval-runs"))
    p.add_argument("--labelers", default=None, help="Comma-separated subset (default: all registered)")
    p.add_argument("--run-id", default=None)
    args = p.parse_args()

    truth_map = _load_ground_truth(args.ground_truth)
    if not truth_map:
        raise SystemExit(
            f"No labeled rows found in {args.ground_truth}. "
            "Fill in `correct_stroke_type` and `correct_*_time` columns, then re-run."
        )
    logger.info(f"Loaded {len(truth_map)} ground-truth strokes")

    names = [n.strip() for n in args.labelers.split(",")] if args.labelers else all_names()
    if not names:
        raise SystemExit("No labelers available. Check API keys / env vars.")
    logger.info(f"Running labelers: {names}")

    run_id = args.run_id or f"run-{uuid.uuid4().hex[:8]}"
    out_dir = args.out_root / f"labelers-{run_id}"
    out_dir.mkdir(parents=True, exist_ok=True)

    tasks = []
    setup_rows = []
    keys = []
    for (sid, idx), truth in truth_map.items():
        session_dir = args.sessions_root / sid
        stroke_input = _build_input(session_dir, idx, truth.get("clip_file", ""))
        if stroke_input is None:
            logger.warning(f"Skipping {sid}#{idx}: missing clip or pose_data")
            for name in names:
                setup_rows.append({
                    "labeler": name,
                    "session_id": sid,
                    "stroke_idx": idx,
                    "truth_stroke_type": truth["stroke_type"],
                    "pred_stroke_type": None,
                    "stroke_type_correct": False,
                    "phase_mae_seconds": None,
                    "phase_mae_phases_scored": 0,
                    "contact_point_abs_error": None,
                    "ordering_valid": False,
                    "latency_ms": None,
                    "input_tokens": None,
                    "output_tokens": None,
                    "cost_cents_estimate": None,
                    "confidence": None,
                    "error": "missing clip or pose_data",
                })
            continue
        for name in names:
            tasks.append(_run_one(name, stroke_input, truth, out_dir))
            keys.append((sid, idx, name))

    started = time.perf_counter()
    run_rows = await asyncio.gather(*tasks) if tasks else []
    rows = setup_rows + run_rows
    elapsed = time.perf_counter() - started
    logger.info(f"Ran {len(rows)} labeler calls in {elapsed:.1f}s")

    # CSV
    csv_path = out_dir / "labeler_comparison.csv"
    if rows:
        fieldnames = sorted({k for r in rows for k in r.keys() if not isinstance(r.get(k), dict)})
        with open(csv_path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
            w.writeheader()
            for r in rows:
                w.writerow(r)
        logger.info(f"Wrote {csv_path}")

    # Summary per labeler. Failures stay in the denominator.
    summary = _summarize_rows(rows, names)

    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2))
    print(f"\nOutputs: {out_dir}")


def main() -> None:
    asyncio.run(_amain())


if __name__ == "__main__":
    main()
