# Labeler D — On-device CoreML + MediaPipe (feasibility sketch only)

No code yet. This document exists so the bake-off decision memo has a fair
read on whether "do it on-device" is actually tractable for us today.

## Two-stage pipeline

1. **Stroke type classifier** — Apple's `MLActionClassifier` (CreateML) trained on
   short pose-data sequences labeled with `forehand / backhand / serve / volley`.
2. **Phase segmenter** — small temporal convnet or 1-D LSTM operating on the
   17-joint sequence, predicting per-frame phase labels. Supervised by hand-labeled
   phase timestamps.

## Why this could work
- All compute stays on-device → 0 latency, 0 $/stroke.
- Apple Vision already gives us per-frame joints (17 keypoints, 30 fps).
- `MLActionClassifier` ships from Apple for exactly this use case.
- The features (joint positions over time) carry much more signal than the current
  single-frame wrist-x-vs-midline heuristic.

## Why it's NOT this quarter's work

**Data volume.** MLActionClassifier typically wants ~50–100 examples per class for
usable accuracy. We have 6 captured sessions today (~14 strokes, skewed heavily
toward forehand). Even with aggressive augmentation we're an order of magnitude
short for a trustworthy model — especially for `serve` (1 example) and `volley`
(0 examples).

**Labeling effort.** Per-frame phase labeling for the segmenter is significantly
more work than stroke-level labeling. ~30s per stroke × 50+ strokes = several hours.

**Compute.** CreateML training is quick (minutes on an M-series Mac). Deployment
path (CoreML bundled in the iOS app) is standard. None of this is hard — it's
just *later* work.

## Recommended treatment in the bake-off

Do not run labeler D against the ground-truth CSV. Instead:

- Record its scores as **"insufficient training data — pending"** in the output.
- Note in the decision memo: on-device is the long-run answer iff the hosted-LLM
  answer (Gemini or Claude) proves too slow / too expensive at scale.
- Trigger point to revisit: when we have 100+ hand-labeled strokes across all
  4 stroke types, OR when hosted costs exceed $0.02/stroke at 1k sessions/day.

## If/when we pick this up

1. Collect a dataset of 200+ strokes (can solicit from TestFlight users with opt-in).
2. Hand-label stroke type + 7 phase timestamps for each.
3. Export joint sequences as CreateML-compatible mlprobes.
4. Train MLActionClassifier (stroke type).
5. Train a separate phase segmenter — PyTorch prototype, convert to CoreML via
   `coremltools`.
6. Ship both models bundled in the app; replace the heuristics in
   `TennisIQ/Services/StrokeDetector.swift`.

Estimated effort once data exists: 1–2 weeks.
