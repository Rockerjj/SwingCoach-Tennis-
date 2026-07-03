"""Labeler A: the existing iOS on-device heuristic (baseline).

This labeler doesn't run any new detection — it just echoes back the labels
the iOS `StrokeDetector` already produced (found in pose_data.json's
detected_strokes[]). Including it in the bake-off lets us score the current
production behavior on the exact same axes as Gemini/Claude/on-device.
"""
from __future__ import annotations

import time

from . import Labeler, LabelerInput, LabelerResult, register


class IOSHeuristicLabeler:
    name = "ios"

    async def label(self, stroke: LabelerInput) -> LabelerResult:
        started = time.perf_counter()
        phases = dict(stroke.ios_phases)  # already absolute session time
        latency_ms = int((time.perf_counter() - started) * 1000)
        stroke_type = stroke.ios_stroke_type or "unknown"
        return LabelerResult(
            stroke_type=stroke_type,  # type: ignore[arg-type]
            phases=phases,
            latency_ms=latency_ms,
            input_tokens=0,
            output_tokens=0,
            cost_cents_estimate=0.0,
            raw_response=None,
        )


register(IOSHeuristicLabeler())
