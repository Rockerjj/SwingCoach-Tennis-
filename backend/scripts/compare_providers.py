"""Run a single captured session through every provider and dump results.

Usage (from the backend/ directory):

    python -m scripts.compare_providers test-data/sessions/<session_id> \\
        [--run-id <run_id>] \\
        [--out-root test-data/eval-runs] \\
        [--providers gemini,opus,sonnet,openai]

Outputs to:

    <out-root>/<run-id>/<session_id>/
        gemini.json | opus.json | sonnet.json | openai.json
        metrics.json

Each provider's output JSON is the AnalysisResponse if the call succeeded,
or {"error": "..."} if it failed. metrics.json captures latency, token counts,
and estimated cost per provider so the eval can be summarized.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import logging
import sys
import time
import uuid
from pathlib import Path
from typing import Any

# Make `app.*` importable when run as `python -m scripts.compare_providers`
# from the backend/ directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

from app.config import get_settings
from app.models import AnalysisResponse, SessionPosePayload
from app.services.gemini_coaching import GeminiCoachingService
from app.services.claude_coaching import ClaudeCoachingService
from app.services.llm_coaching import LLMCoachingService

from scripts.pricing import estimate_cost_cents
from scripts.session_loader import load_captured_session

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("compare_providers")


ALL_PROVIDERS = ["gemini", "opus", "sonnet", "openai"]


def _meta(model: str, latency_ms: int, usage: dict | None) -> dict:
    in_tok = (usage or {}).get("input_tokens")
    out_tok = (usage or {}).get("output_tokens")
    cost = None
    if in_tok is not None and out_tok is not None:
        cost = estimate_cost_cents(model, in_tok, out_tok)
    return {
        "model": model,
        "latency_ms": latency_ms,
        "input_tokens": in_tok,
        "output_tokens": out_tok,
        "cost_cents_estimate": cost,
    }


async def _run_gemini(
    payload: SessionPosePayload,
    frames: list[bytes],
    clips: list[tuple[float, bytes]],
) -> tuple[AnalysisResponse, dict]:
    """Gemini's underlying SDK call is synchronous, so off-load it to a
    worker thread to avoid blocking other providers in the gather."""
    settings = get_settings()
    started = time.perf_counter()

    container: dict = {}

    def _call() -> AnalysisResponse:
        coaching = GeminiCoachingService()
        result = asyncio.run(coaching.analyze_session(payload, frames, clips or None))
        container["usage"] = coaching.last_usage
        return result

    result = await asyncio.to_thread(_call)
    latency_ms = int((time.perf_counter() - started) * 1000)
    return result, _meta(settings.gemini_model, latency_ms, container.get("usage"))


async def _run_claude(
    payload: SessionPosePayload,
    frames: list[bytes],
    model: str,
) -> tuple[AnalysisResponse, dict]:
    started = time.perf_counter()
    coaching = ClaudeCoachingService(model=model)
    result = await coaching.analyze_session(payload, frames)
    latency_ms = int((time.perf_counter() - started) * 1000)
    return result, _meta(model, latency_ms, coaching.last_usage)


async def _run_openai(
    payload: SessionPosePayload,
    frames: list[bytes],
) -> tuple[AnalysisResponse, dict]:
    settings = get_settings()
    started = time.perf_counter()
    coaching = LLMCoachingService()
    result = await coaching.analyze_session(payload, frames)
    latency_ms = int((time.perf_counter() - started) * 1000)
    return result, _meta(settings.openai_model, latency_ms, coaching.last_usage)


async def _safe(name: str, coro) -> tuple[str, dict]:
    """Wrap a provider call so one failure doesn't crash the rest of the run."""
    try:
        result, meta = await coro
        return name, {
            "ok": True,
            "result": json.loads(result.model_dump_json()),
            "meta": meta,
        }
    except Exception as e:
        logger.exception(f"Provider {name} failed")
        return name, {
            "ok": False,
            "error": f"{type(e).__name__}: {e}",
            "meta": {"model": "unknown", "latency_ms": None},
        }


async def compare_session(
    session_dir: Path,
    out_dir: Path,
    providers: list[str],
) -> dict:
    payload, frames, clips = load_captured_session(session_dir)
    settings = get_settings()

    logger.info(
        f"Loaded session {session_dir.name}: "
        f"{len(payload.detected_strokes)} strokes, {len(frames)} frames, {len(clips)} clips"
    )

    tasks: dict[str, Any] = {}
    if "gemini" in providers and settings.gemini_api_key:
        tasks["gemini"] = _safe("gemini", _run_gemini(payload, frames, clips))
    if "opus" in providers and settings.anthropic_api_key:
        tasks["opus"] = _safe("opus", _run_claude(payload, frames, settings.anthropic_opus_model))
    if "sonnet" in providers and settings.anthropic_api_key:
        tasks["sonnet"] = _safe("sonnet", _run_claude(payload, frames, settings.anthropic_sonnet_model))
    if "openai" in providers and settings.openai_api_key:
        tasks["openai"] = _safe("openai", _run_openai(payload, frames))

    skipped = [p for p in providers if p not in tasks]
    for p in skipped:
        logger.warning(f"Skipping {p}: missing API key in environment")

    results = await asyncio.gather(*tasks.values())
    by_provider = dict(results)

    out_dir.mkdir(parents=True, exist_ok=True)
    metrics: dict[str, Any] = {
        "session_id": session_dir.name,
        "stroke_count": len(payload.detected_strokes),
        "key_frame_count": len(frames),
        "stroke_clip_count": len(clips),
        "providers": {},
    }

    for name, payload_result in by_provider.items():
        path = out_dir / f"{name}.json"
        path.write_text(json.dumps(payload_result, indent=2))
        meta = payload_result.get("meta", {})
        metrics["providers"][name] = {
            "ok": payload_result["ok"],
            "model": meta.get("model"),
            "latency_ms": meta.get("latency_ms"),
            "input_tokens": meta.get("input_tokens"),
            "output_tokens": meta.get("output_tokens"),
            "cost_cents_estimate": meta.get("cost_cents_estimate"),
            "error": payload_result.get("error"),
        }

    for name in skipped:
        metrics["providers"][name] = {"ok": False, "error": "skipped: missing API key"}

    (out_dir / "metrics.json").write_text(json.dumps(metrics, indent=2))
    return metrics


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Run captured session through all providers")
    p.add_argument("session_dir", type=Path, help="Path to test-data/sessions/<session_id>")
    p.add_argument("--run-id", default=None, help="Eval run id (default: random uuid prefix)")
    p.add_argument("--out-root", default="test-data/eval-runs", type=Path)
    p.add_argument(
        "--providers",
        default=",".join(ALL_PROVIDERS),
        help="Comma-separated subset of: gemini,opus,sonnet,openai",
    )
    return p.parse_args()


async def _amain() -> None:
    args = parse_args()
    providers = [p.strip() for p in args.providers.split(",") if p.strip()]
    bad = set(providers) - set(ALL_PROVIDERS)
    if bad:
        raise SystemExit(f"Unknown providers: {sorted(bad)}; allowed: {ALL_PROVIDERS}")

    run_id = args.run_id or f"run-{uuid.uuid4().hex[:8]}"
    session_dir: Path = args.session_dir
    out_dir = args.out_root / run_id / session_dir.name

    metrics = await compare_session(session_dir, out_dir, providers)
    print(json.dumps(metrics, indent=2))
    print(f"\nResults written to: {out_dir}")


def main() -> None:
    asyncio.run(_amain())


if __name__ == "__main__":
    main()
