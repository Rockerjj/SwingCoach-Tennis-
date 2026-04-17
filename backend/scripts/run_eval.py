"""Run compare_providers across every captured session.

Usage (from the backend/ directory):

    python -m scripts.run_eval [--sessions-root test-data/sessions] \\
        [--out-root test-data/eval-runs] [--run-id <id>] \\
        [--providers gemini,opus,sonnet,openai]

Aggregates each session's metrics.json into:

    <out-root>/<run-id>/summary.csv
    <out-root>/<run-id>/summary.json
"""
from __future__ import annotations

import argparse
import asyncio
import csv
import json
import logging
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from scripts.compare_providers import ALL_PROVIDERS, compare_session

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("run_eval")


CSV_COLUMNS = [
    "session_id",
    "provider",
    "model",
    "ok",
    "latency_ms",
    "input_tokens",
    "output_tokens",
    "cost_cents_estimate",
    "error",
]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run all sessions through all providers")
    p.add_argument("--sessions-root", type=Path, default=Path("test-data/sessions"))
    p.add_argument("--out-root", type=Path, default=Path("test-data/eval-runs"))
    p.add_argument("--run-id", default=None)
    p.add_argument("--providers", default=",".join(ALL_PROVIDERS))
    return p.parse_args()


async def _amain() -> None:
    args = parse_args()
    providers = [p.strip() for p in args.providers.split(",") if p.strip()]
    bad = set(providers) - set(ALL_PROVIDERS)
    if bad:
        raise SystemExit(f"Unknown providers: {sorted(bad)}; allowed: {ALL_PROVIDERS}")

    if not args.sessions_root.is_dir():
        raise SystemExit(f"Sessions root not found: {args.sessions_root}")

    session_dirs = sorted(p for p in args.sessions_root.iterdir() if p.is_dir())
    if not session_dirs:
        raise SystemExit(f"No session directories found under {args.sessions_root}")

    run_id = args.run_id or f"run-{uuid.uuid4().hex[:8]}"
    run_root = args.out_root / run_id
    run_root.mkdir(parents=True, exist_ok=True)

    logger.info(f"Eval run {run_id}: {len(session_dirs)} sessions, providers={providers}")

    all_metrics: list[dict] = []
    for i, sd in enumerate(session_dirs, start=1):
        logger.info(f"[{i}/{len(session_dirs)}] {sd.name}")
        out_dir = run_root / sd.name
        try:
            metrics = await compare_session(sd, out_dir, providers)
            all_metrics.append(metrics)
        except Exception as e:
            logger.exception(f"Session {sd.name} failed entirely: {e}")
            all_metrics.append({"session_id": sd.name, "error": str(e), "providers": {}})

    # Aggregate JSON
    (run_root / "summary.json").write_text(json.dumps(all_metrics, indent=2))

    # Flat CSV — one row per (session, provider)
    csv_path = run_root / "summary.csv"
    with csv_path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=CSV_COLUMNS)
        w.writeheader()
        for m in all_metrics:
            session_id = m.get("session_id", "?")
            for provider, pmeta in m.get("providers", {}).items():
                w.writerow({
                    "session_id": session_id,
                    "provider": provider,
                    "model": pmeta.get("model"),
                    "ok": pmeta.get("ok"),
                    "latency_ms": pmeta.get("latency_ms"),
                    "input_tokens": pmeta.get("input_tokens"),
                    "output_tokens": pmeta.get("output_tokens"),
                    "cost_cents_estimate": pmeta.get("cost_cents_estimate"),
                    "error": pmeta.get("error"),
                })

    print(f"\nRun complete: {run_root}")
    print(f"  summary.json: {run_root / 'summary.json'}")
    print(f"  summary.csv:  {csv_path}")
    print(f"\nNext: python -m scripts.build_score_sheet {run_id}")


def main() -> None:
    asyncio.run(_amain())


if __name__ == "__main__":
    main()
