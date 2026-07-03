# Tennique Accuracy Push — Handoff for Fresh Context

> **Read this first.** You are being handed a live project mid-flight. The user (Josh, the founder) has done all the setup and is asking you to take a fresh architectural look at accuracy. Do not assume the current design is correct. Do not assume prior conversations were right. Read what's in `main`, then challenge assumptions.
>
> Everything below is state as of merge commit `09cd190` on `main`.

---

## 1) What Tennique is

iOS app + FastAPI backend. User records a tennis session on iPhone. On device, we extract pose keypoints and detect candidate stroke apexes. Backend runs a coaching LLM against the pose + key frames + short stroke clips and returns a per-session analysis (top priority, per-stroke phase notes, drill recommendations).

Target launch checklist lives in [`LAUNCH-TRACKER.md`](LAUNCH-TRACKER.md). Read it — it is Josh's own quality bar.

## 2) The accuracy problem, precisely

**Stroke type identification is unreliable.** On Josh's real recordings (May 9, two sessions), several strokes were mislabeled — a forehand called a backhand, backhands merged with other strokes, etc. The result: coaching feedback is applied to the wrong swing type, which is a credibility-killer for a coaching app.

**Root cause is not one thing.** It is a chain:

1. iOS-side `StrokeDetector` uses wrist-velocity thresholds to find stroke apexes. It has no model of what a stroke looks like — it hard-codes right-handed geometry and guesses stroke type from motion direction. This is the labels the shipping app uses.
2. Backend has a `stroke_relabeler` service that runs hosted labelers (Gemini / Claude / Sonnet) on the stroke clip to overwrite iOS's guess with a stronger label. **It is gated OFF by default** in `backend/app/config.py` (`relabel_strokes: bool = False`).
3. The coaching LLM (Claude Opus 4.7) receives the iOS labels as ground truth. If iOS says "backhand," the coach coaches a backhand, regardless of what actually happened on the video.

So today, users get the accuracy of a velocity-threshold heuristic even though we have hosted multimodal LLMs sitting one flag away.

## 3) Current architecture (pipeline)

```
┌────────────────────────────────────────────────────────────────────────┐
│  iPhone (TennisIQ target)                                              │
│                                                                        │
│  Camera → AVAsset → PoseEstimationService                              │
│                       └── PoseEngine (protocol)                        │
│                             ├── MediaPipePoseEngine (33 keypoints)     │
│                             └── VisionPoseEngine (17 keypoints, fallback)  │
│                                                                        │
│  Frames → StrokeDetector (velocity heuristic)                          │
│                       ↓                                                │
│         Sampled strokes + key frames + stroke clips + pose JSON        │
│                       ↓                                                │
│         AnalysisAPIService → POST /api/v1/sessions/analyze (multipart) │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  FastAPI backend (Railway prod)                                        │
│                                                                        │
│  routes/sessions.py → analyze_session()                                │
│     ├── (optional, currently OFF) stroke_relabeler.relabel_all()       │
│     │      └── runs one of: mediapipe_gemini / mediapipe_claude /      │
│     │                        mediapipe_sonnet / gemini_video /         │
│     │                        claude_frames / mediapipe_heuristic       │
│     └── coaching provider (default: claude_opus 4.7)                   │
│                       ↓                                                │
│              AnalysisResponse (tool-use JSON)                          │
└────────────────────────────────────────────────────────────────────────┘
```

The labeler bake-off harness (`backend/scripts/eval_labelers.py`) is a separate offline pipeline. It reads captured session fixtures + a hand-labeled ground-truth CSV, runs every labeler, and scores them. **It never touches production.**

## 4) Where accuracy actually is today (2026-05-09 bake-off, N=13 fixture strokes)

Ground truth is 13 hand-labeled strokes across 6 captured sessions. **Almost entirely forehands** — no meaningful backhand / serve / volley signal. Take these numbers as directional only.

| Labeler              | Stroke-type acc | Contact-MAE   | Latency p50 | Notes                                     |
|----------------------|-----------------|---------------|-------------|-------------------------------------------|
| mediapipe_sonnet     | 100%            | 0.629s        | 143 s       | Best accuracy, too slow for prod          |
| mediapipe_gemini     | 92%             | 0.725s        | **16 s**    | Best speed/accuracy tradeoff              |
| mediapipe_claude     | 69%             | **0.494s**    | 140 s       | Best contact timing, worst type ID        |
| **ios (production)** | **62%**         | 0.514s        | 0 ms        | **What real users get today**             |
| mediapipe_heuristic  | 23%             | 0.72s         | 1.6 s       | Broken — labels everything "volley"       |
| gemini_video         | 0%              | —             | —           | All errored (unfixed bug)                 |
| claude_frames        | 0%              | —             | —           | All errored (unfixed bug)                 |

## 5) What's been built so far (what's on main)

**MediaPipe pose engine (iOS).** Full 33-keypoint BlazePose ships in the app bundle at `TennisIQ/Resources/pose_landmarker_full.task`. Selected via `AppConstants.FeatureFlags.poseEngine = .mediapipe`. Falls back to Vision (17 keypoints) if the .task fails to load. Logs the active engine per session. Verified live on iPhone with Apple A16 GPU.

**Pluggable labeler protocol.** `backend/app/services/labelers/` has 7 labeler implementations behind a shared `Labeler` protocol with a `LabelerInput`/`LabelerResult` dataclass pair. Registered by name; the eval harness discovers them dynamically.

**Bake-off harness.** `backend/scripts/eval_labelers.py` — run each labeler on the fixture set, score against ground truth, emit per-run CSV + summary JSON. Failures count as failures (not excluded). Confusion matrix, per-phase MAE, contact-MAE, ordering validity, cost/latency percentiles.

**Ground-truth tooling.** `backend/scripts/build_ground_truth_template.py` walks captured sessions and generates a pre-populated CSV skeleton for hand-labeling. Also `backend/test-data/ground-truth/sessions.csv` is currently 13 rows — Josh's own launch bar says ≥50, target 100+.

**Diagnosis capture.** Debug builds now set `sendAllStrokesForEval` + `uploadSourceVideoForEval` so every detected stroke is uploaded and the raw session video is preserved for offline replay. Backend `_capture_payload` persists `source_video/`, per-clip filenames, iOS's `original_strokes` snapshot, and a per-labeler-attempt `relabel_debug.json` + `relabel_summary.json`. Removes the "is my relabeler doing anything?" mystery.

**Relabeler with observability.** `backend/app/services/stroke_relabeler.py` runs primary + fallback labelers, threads handedness through `LabelerInput`, gates overwrites on `confidence >= 0.75` + valid ordering + contact-in-clip, and emits debug events. **Off by default.**

**Handedness + disambiguation in prompts.** `mediapipe_gemini.py` + `mediapipe_claude.py` inject player handedness and dominant/non-dominant side into the user prompt, plus explicit stroke-type geometry rules. `phase_detector_gemini.py` system prompt: "Do not trust the app's initial stroke guess."

## 6) Recommended fix ladder (from prior analysis — challenge if you disagree)

| Order | Change                                                      | Expected lift              | Effort   | Risk |
|-------|-------------------------------------------------------------|----------------------------|----------|------|
| 1     | **Turn relabeler ON with `mediapipe_gemini`**               | +25–30 pp stroke-type acc  | 1 day    | Adds ~16 s p50 latency; ~$0.01–0.05/session |
| 2     | **Hand-label 20+ new swings → expand ground truth to 30+**  | Validates #1 with real numbers | 30 min | None |
| 3     | Iterate prompts on the winning labeler                      | +5–10 pp                   | 1 day    | None |
| 4     | Add handedness detection on iOS                             | Fixes left-handers         | 2 days   | Helps fallback path |
| 5     | Refactor iOS heuristic into a fallback-only role             | Better when relabeler off  | 3 days   | None |
| 6     | Custom-train tennis stroke classifier                       | Maybe +5 pp over best LLM  | **3+ months** | High — data bottleneck |

Do not do #6 until #1–5 are exhausted. Hosted multimodal LLMs are already state-of-the-art at video understanding.

## 7) Constraints Fable should honor

- **LAUNCH-TRACKER quality bars** are non-negotiable ship gates: ≥90% stroke-type accuracy on frozen eval set, ≥95% analysis success rate, ≥98% phase ordering validity, contact-point MAE ≤ 0.25s, session p50 latency ≤ 90s, p95 ≤ 180s, ≥99% crash-free.
- **Ground truth is ~13 strokes and forehand-heavy.** Any decision framed as "the eval shows X" should treat this as pilot data, not evidence. The bake-off harness is real; the corpus is not.
- **Latency budget is the tightest constraint.** Users are on cellular. Sonnet at 143s p50 kills the UX; Gemini at 16s is livable behind a "analyzing…" screen. **iOS-side inference costs 0 latency.**
- **Cost is not the primary constraint** (Josh has explicitly said "don't worry about API costs" during eval work), but production per-session cost matters.
- **Do not touch the coaching layer.** The default coaching provider is Claude Opus 4.7 and that was decided by a prior blind eval documented in `backend/test-data/eval-runs/eval-v1/winner.md`. This project is about *inputs* to that layer.
- **Do not train custom models yet.** See #6 above.
- **Do not add features, refactor, or introduce abstractions beyond what the task requires** (see [`CLAUDE.md`](CLAUDE.md) — Josh follows Karpathy principles: surgical changes, no speculative flexibility).

## 8) Key files map

**iOS pipeline (Swift)**
- `TennisIQ/Services/PoseEstimationService.swift` — orchestrates pose extraction. Reads `FeatureFlags.poseEngine`, calls `warmUp()`, falls back to Vision on load failure.
- `Pose/PoseEngine.swift` — protocol.
- `Pose/MediaPipePoseEngine.swift` — 33-keypoint MediaPipe Tasks. Bundled model.
- `Pose/VisionPoseEngine.swift` — 17-keypoint fallback.
- `TennisIQ/Services/StrokeDetector.swift` — **the velocity-threshold heuristic that is the real accuracy bottleneck for stroke type**. Right-hand hardcoded. Read this before proposing changes.
- `TennisIQ/ViewModels/AnalysisViewModel.swift` — assembles session payload. Note `sendAllStrokesForEval` / `uploadSourceVideoForEval` debug flags.
- `TennisIQ/Services/AnalysisAPIService.swift` — multipart POST to `/api/v1/sessions/analyze`.
- `TennisIQ/Utilities/Constants.swift` — feature flags live here.

**Backend pipeline (Python)**
- `backend/app/routes/sessions.py` — `/analyze` endpoint. Handles multipart, calls relabeler, calls coaching provider, persists debug capture.
- `backend/app/services/stroke_relabeler.py` — the gated relabeling service.
- `backend/app/services/labelers/__init__.py` — Labeler protocol + registry + LabelerInput/Result.
- `backend/app/services/labelers/mediapipe_gemini.py` — Gemini video labeler with MediaPipe trajectory. **The recommended default.**
- `backend/app/services/labelers/mediapipe_claude.py` — Claude equivalent.
- `backend/app/services/labelers/mediapipe_sonnet.py` — Sonnet equivalent.
- `backend/app/services/labelers/mediapipe_heuristic.py` — server-side MediaPipe + heuristic. **Currently broken (labels everything "volley"). Do not use as a fallback until fixed.**
- `backend/app/services/labelers/gemini_video.py` — pure Gemini video (no trajectory). **All 13 test strokes errored — bug unresolved.**
- `backend/app/services/labelers/claude_frames.py` — Claude on key frames. **Same, all errored.**
- `backend/app/prompts/phase_detector_gemini.py` — Gemini system prompt.
- `backend/app/prompts/phase_detector_claude.py` — Claude system prompt.
- `backend/app/config.py` — `relabel_strokes: bool` — **this is the flag to flip to turn accuracy path on.**

**Eval / ground truth**
- `backend/scripts/eval_labelers.py` — bake-off harness.
- `backend/scripts/build_ground_truth_template.py` — CSV skeleton builder from captured sessions.
- `backend/test-data/ground-truth/sessions.csv` — 13 hand-labeled rows. `backend/test-data/sessions/` is gitignored (fixtures live locally).

## 9) What Josh explicitly wants you (Fable) to answer

1. **Should the shipped app run the relabeler on every session, or is there a smarter architecture** — e.g. on-device classification with a small model, hybrid where iOS labels drive UX and backend labels drive coaching, server-side stroke detection replacing on-device StrokeDetector entirely?
2. **Is `StrokeDetector` (iOS) fundamentally the wrong abstraction?** It conflates apex detection (temporal) with stroke classification (semantic). Should those be two stages, with classification always deferred to the backend?
3. **What's the minimum viable ground-truth corpus to actually launch?** Josh's bar is 50 min / 100 target. Is that right, or is variety (left-handers, serves, volleys, low light, angles) the actual limiting axis?
4. **Should we drop the mediapipe_heuristic / gemini_video / claude_frames labelers entirely?** Two are broken, one is regressive. What's the maintenance cost of keeping them vs the optionality?
5. **Is there value in a per-stroke confidence score returned all the way to the UI**, so the coaching card can say "we're 60% sure this was a backhand — want to correct it?" That's a data-collection loop as much as a UX feature.
6. **Do we need a training-mode capture on iOS** (a separate "record for eval" flow that's slower, higher-fidelity, and asks the user to label as they go)?

Answer these before proposing implementation. Recommend, don't defer.

## 10) How to verify the current state

```bash
# Confirm main matches
git log --oneline -5

# Backend env
cd backend && ./venv/bin/python -c "import mediapipe, cv2, anthropic, google.genai, openai, dotenv; print('deps OK')"

# Run the bake-off (13 strokes, all 7 labelers)
./venv/bin/python -m scripts.eval_labelers \
    --labelers ios,mediapipe_heuristic,mediapipe_gemini,mediapipe_claude,mediapipe_sonnet,gemini_video,claude_frames

# Ground truth
wc -l test-data/ground-truth/sessions.csv
head -1 test-data/ground-truth/sessions.csv

# Build the app: open workspace (NOT project) so Pods link
cd ..
open TennisIQ.xcworkspace

# Backend server (LAN) — MUST run through the venv or anthropic import fails
cd backend && ./venv/bin/python main.py

# iPhone DEBUG build points at http://10.0.0.48:8000 (LAN IP). Update
# TennisIQ/Utilities/Constants.swift → API.debugBaseURL if your Mac IP
# changed (ipconfig getifaddr en0).
```

## 11) What to do first

1. **Read [`LAUNCH-TRACKER.md`](LAUNCH-TRACKER.md)** end to end.
2. **Read `TennisIQ/Services/StrokeDetector.swift`** — this is the accuracy bottleneck no one's talking about.
3. **Read `backend/app/services/stroke_relabeler.py`** and `backend/app/routes/sessions.py:analyze_session` to see the accuracy path that is currently disabled.
4. **Run the bake-off** on the 13-stroke corpus to reproduce the numbers in §4.
5. **Then respond with your architectural read** — answering the 6 questions in §9 with recommendations, not options.

Do not start coding until Josh confirms your architectural direction.
