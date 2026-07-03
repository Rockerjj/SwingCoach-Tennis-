# Stroke Accuracy Fable Handoff

Last updated: 2026-07-03

## Purpose

This document is meant to be pasted into Fable / Claude Code as context for a possible re-architecture of TennisIQ's swing evaluation pipeline.

The current work focuses on improving stroke classification accuracy and model output quality. The main lesson so far is that accuracy problems are not only prompt problems. The model can only classify what the app sends it. If the iOS app detects the wrong contact moment, clips the wrong 3 seconds, or filters out strokes before backend relabeling, Gemini/Claude can still fail even with better prompts.

## Current Goal

Make the swing evaluation pipeline measurable and debuggable before deciding whether to train a custom model.

Immediate goals:

- Preserve all candidate strokes during evaluation.
- Capture enough artifacts to replay and inspect failures.
- Separate failure modes: missed stroke, bad contact timestamp, bad clip, model misclassification, confidence calibration, phase timing.
- Compare iOS heuristic, MediaPipe heuristic, MediaPipe + Gemini, and MediaPipe + Sonnet on the same labeled clips.
- Only train a tennis-specific classifier if clean clips plus prompt/model improvements still miss common stroke patterns.

## Current Model Strategy

The intended stack is:

- On-device pose: MediaPipe Pose Landmarker on iOS, with Vision fallback.
- First-pass stroke candidate generation: iOS `StrokeDetector`.
- Backend relabeling: `mediapipe_gemini` primary, `mediapipe_sonnet` fallback.
- Final coaching output: Claude Opus by default.
- Offline eval: run every labeler against hand-labeled ground truth.

Important distinction:

- The app's `StrokeDetector` should be treated as a candidate generator, not as ground truth.
- Hosted models should receive candidate clips and pose trajectories, then relabel type and phases.
- Final coaching should use corrected relabeled strokes, not raw iOS guesses.

## Why Accuracy Was Failing

Observed issue: after running test videos, several strokes were misidentified.

Likely causes found in code:

- The app previously sampled representative strokes by predicted stroke type before backend relabeling.
- If iOS guessed the type incorrectly, the backend might never receive the full set needed to correct the session.
- The backend labeler classifies single clips. If the clip is not centered on true contact, prompt changes cannot fully fix the result.
- The iOS `StrokeDetector` uses wrist velocity and simple geometry. That can generate useful candidates, but it is brittle for volleys, serves, side-angle recordings, left-handed strokes, occlusion, and ambiguous follow-throughs.

## Implemented Changes

### iOS Eval Capture Path

Files changed:

- `TennisIQ/ViewModels/AnalysisViewModel.swift`
- `TennisIQ/Services/AnalysisAPIService.swift`
- `TennisIQ/Utilities/Constants.swift`

What changed:

- Debug eval builds now send all detected strokes to the backend.
- Production can still sample representative strokes for cost and output quality.
- Debug eval builds upload the original source video.
- Debug eval builds preserve more key frames around all candidate strokes.
- New flags:
  - `AppConstants.FeatureFlags.sendAllStrokesForEval`
  - `AppConstants.FeatureFlags.uploadSourceVideoForEval`

Current behavior:

```swift
let strokesForAnalysis = AppConstants.FeatureFlags.sendAllStrokesForEval
    ? extraction.detectedStrokes
    : selectRepresentativeStrokes(from: extraction.detectedStrokes)
```

In debug mode, the backend sees the full candidate set. Final coaching can still use sampled relabeled strokes.

### Backend Capture Path

Files changed:

- `backend/app/routes/sessions.py`
- `backend/app/services/stroke_relabeler.py`

Capture now writes:

- `metadata.json`
- `pose_data.json`
- `key_frames/key_frame_*.jpg`
- `stroke_clips/stroke_clip_*.mp4`
- `source_video/<original filename>`
- `relabel_debug.json`
- `relabel_summary.json`

`metadata.json` includes:

- session ID
- user ID
- received timestamp
- key frame count
- stroke clip count
- stroke clip filenames and timestamps
- source video metadata
- original iOS stroke guesses and contact timestamps

`relabel_debug.json` includes one record per labeler attempt:

- stroke index
- original iOS type
- original contact timestamp
- matched clip timestamp
- clip filename
- clip start
- clip duration
- labeler name
- predicted type
- confidence
- phase count
- ordering validity
- error, if any
- validation result
- overwrite status

`relabel_summary.json` groups those attempts per stroke for faster inspection.

### Backend Relabeling Flow

File changed:

- `backend/app/services/stroke_relabeler.py`

Current relabeling flow:

1. Match each detected stroke to the nearest clip by contact timestamp.
2. Run `mediapipe_gemini`.
3. If it errors or returns `unknown`, run `mediapipe_sonnet`.
4. Validate the result:
   - no labeler error
   - not `unknown`
   - `confidence >= 0.75`
   - all phases present
   - phases strictly ordered
   - contact point inside clip bounds
5. Overwrite the iOS stroke only when validation passes.
6. Return relabeled payload plus debug events.

Important design choice:

- Relabeling runs on all candidate strokes.
- Final coaching samples relabeled strokes afterward.
- This separates detection accuracy from coaching cost.

Backend sampling function:

```python
def _select_representative_strokes(payload: SessionPosePayload, max_per_type: int = 2) -> SessionPosePayload:
    ...
```

This should happen after relabeling, not before.

### Prompt Improvements

Files changed:

- `backend/app/prompts/phase_detector_gemini.py`
- `backend/app/services/labelers/mediapipe_gemini.py`
- `backend/app/services/labelers/mediapipe_claude.py`

Prompt changes:

- The app's iOS guess is weak context, not trusted truth.
- Handedness is included.
- Dominant side and non-dominant side are explicitly described.
- Forehand/backhand/serve/volley disambiguation is stronger.
- The model is told to use an evidence checklist:
  - dominant wrist side relative to torso midpoint
  - wrist height relative to nose/shoulders
  - wrist path length
  - swing duration
  - shoulder/hip rotation
  - overhead vs compact volley vs full groundstroke

This is still a prompt-level improvement. It does not replace the need for clean clips and labeled evals.

### Eval Harness Improvements

Files changed:

- `backend/scripts/eval_labelers.py`
- `backend/scripts/build_ground_truth_template.py`

`eval_labelers.py` now reports:

- attempted
- succeeded
- unknown
- errored
- overwritten
- stroke type accuracy
- phase coverage rate
- phase MAE
- contact-point MAE
- ordering valid rate
- latency median and p95
- cost estimate
- confusion matrix
- clip contains true contact rate
- clip contact offset mean
- failure modes

Failure modes include:

- `labeler_error`
- `clip_missed_contact`
- `unknown_output`
- `type_misclassified_with_contact`
- `phase_order_invalid`
- `contact_timing_error`
- `phase_coverage_gap`
- `correct`

`build_ground_truth_template.py` generates a CSV skeleton from captured sessions:

```bash
python3 -m scripts.build_ground_truth_template \
  --sessions-root test-data/sessions \
  --out test-data/ground-truth/sessions.csv
```

The generated CSV includes:

- session ID
- stroke index
- clip file
- iOS stroke type
- iOS contact time
- correct stroke type
- camera angle
- visibility quality
- failure notes
- iOS phase times
- correct phase times

## How To Run Local Capture

From `backend/`:

```bash
DEBUG_CAPTURE_PAYLOADS=true \
RELABEL_STROKES=true \
GEMINI_MODEL=gemini-3-flash-preview \
COACHING_PROVIDER=claude_opus \
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Then run the iOS app in Debug so it points at the local backend configured in:

`TennisIQ/Utilities/Constants.swift`

Expected output after recording:

```text
backend/test-data/sessions/<session_id>/
  metadata.json
  pose_data.json
  relabel_debug.json
  relabel_summary.json
  key_frames/
  stroke_clips/
  source_video/
```

## How To Run Eval

After capture, generate a ground truth template:

```bash
cd backend
python3 -m scripts.build_ground_truth_template \
  --sessions-root test-data/sessions \
  --out test-data/ground-truth/sessions.csv
```

Manually fill:

- `correct_stroke_type`
- `correct_contact_point_time`
- other `correct_*_time` fields if possible
- `camera_angle`
- `visibility_quality`
- `failure_notes`

Then run:

```bash
python3 -m scripts.eval_labelers \
  --ground-truth test-data/ground-truth/sessions.csv \
  --sessions-root test-data/sessions \
  --out-root test-data/eval-runs \
  --labelers ios,mediapipe_heuristic,mediapipe_gemini,mediapipe_sonnet
```

Optional high-cost benchmark:

```bash
python3 -m scripts.eval_labelers \
  --ground-truth test-data/ground-truth/sessions.csv \
  --sessions-root test-data/sessions \
  --out-root test-data/eval-runs \
  --labelers ios,mediapipe_heuristic,mediapipe_gemini,mediapipe_sonnet,mediapipe_claude
```

## Merge Gates

Do not merge relabeling as production-default until:

- At least 50 labeled strokes exist for the immediate gate.
- Backend sees all candidate strokes during eval.
- `mediapipe_gemini` or an ensemble beats iOS/heuristic by a clear margin.
- Stroke type accuracy is at least 90 percent.
- Contact-point MAE is at most 0.25 seconds.
- Error and unknown rates are counted in the denominator.
- Failure modes show the model is actually the bottleneck, not clip/contact extraction.

## When To Train

Do not train yet.

Train only if:

- Clips contain true contact.
- Labelers see good pose trajectories.
- Prompt/model comparisons still miss common tennis-specific cases.
- There are enough labeled examples to avoid overfitting.

Recommended training path:

- Start with a lightweight pose-trajectory classifier, not a full video model.
- Collect 300 to 500 labeled stroke clips minimum.
- Balance forehand, backhand, serve, volley.
- Store:
  - stroke type
  - contact time
  - handedness
  - camera angle
  - visibility quality
  - failure notes
- Train on features:
  - dominant wrist velocity
  - wrist side relative to shoulder/hip midpoint
  - wrist height relative to shoulders/nose
  - shoulder/hip rotation
  - swing duration
  - compactness / wrist path length
  - vertical motion for serves
- Use the classifier as a cheap first pass.
- Send low-confidence or ambiguous cases to Gemini/Sonnet.

## Recommended Re-Architecture Direction

The current pipeline is usable for diagnosis, but the long-term architecture should separate four concepts:

1. Candidate generation
2. Clip/contact validation
3. Stroke classification
4. Coaching generation

Suggested future structure:

```text
iOS Video
  -> Pose Extraction
  -> Candidate Stroke Generator
  -> Candidate Clip Export
  -> Backend Capture
  -> Clip/Contact Validator
  -> Stroke Labeler Ensemble
  -> Confidence Gate
  -> Relabeled Session Payload
  -> Coaching Model
  -> User-Facing Analysis
```

Candidate generation should optimize recall. It is better to send extra candidate clips than to miss strokes before relabeling.

Classification should optimize precision and confidence calibration.

Coaching should not perform primary classification. It should explain corrected evidence.

## Specific Re-Architecture Questions For Fable

Ask Fable to evaluate:

- Should stroke candidate generation move fully to the backend where full video and all pose frames are available?
- Should the app upload one compressed source video plus pose JSON instead of many per-stroke clips?
- Should backend create clips around multiple candidate contact peaks instead of trusting iOS clip boundaries?
- Should we add a deterministic clip/contact validator before LLM classification?
- Should final coaching be split into two calls: structured mechanics scoring first, prose coaching second?
- Should we introduce an ensemble policy: Gemini primary, Sonnet fallback, heuristic tie-breaker?
- Should confidence calibration be learned from eval data?
- Should the pose-trajectory classifier become the primary stroke type model once we have enough labels?

## Files Most Relevant To Re-Architecture

iOS:

- `TennisIQ/ViewModels/AnalysisViewModel.swift`
- `TennisIQ/Services/PoseEstimationService.swift`
- `TennisIQ/Services/StrokeDetector.swift`
- `TennisIQ/Services/AnalysisAPIService.swift`
- `TennisIQ/Utilities/Constants.swift`
- `Pose/MediaPipePoseEngine.swift`
- `Pose/VisionPoseEngine.swift`
- `Pose/PoseEngine.swift`

Backend:

- `backend/app/routes/sessions.py`
- `backend/app/services/stroke_relabeler.py`
- `backend/app/services/labelers/__init__.py`
- `backend/app/services/labelers/mediapipe_gemini.py`
- `backend/app/services/labelers/mediapipe_sonnet.py`
- `backend/app/services/labelers/mediapipe_claude.py`
- `backend/app/services/labelers/mediapipe_heuristic.py`
- `backend/app/services/labelers/ios_heuristic.py`
- `backend/app/prompts/phase_detector_gemini.py`
- `backend/app/prompts/phase_detector_claude.py`
- `backend/scripts/eval_labelers.py`
- `backend/scripts/build_ground_truth_template.py`
- `backend/scripts/pricing.py`

## Current Known Risks

- Debug eval mode may upload large source videos. This is intended for local/staging only.
- `DEBUG_CAPTURE_PAYLOADS` must never be enabled in production.
- `RELABEL_STROKES` is still not proven production-safe until eval thresholds are met.
- Final coaching may still summarize only representative strokes, which is intended, but the UX should make clear whether it analyzed all strokes or a representative set.
- The iOS command-line build has previously hit Xcode/iOS platform component issues on some dates. The latest simulator build passed with warnings only.

## Verification Already Run

Backend:

```bash
python3 -m unittest discover -s tests
python3 -m compileall app scripts tests
```

iOS:

```bash
xcodebuild -quiet -workspace "TennisIQ.xcworkspace" -scheme TennisIQ -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Latest iOS simulator build completed with exit code 0 and warnings only.

Known warnings:

- `VisionPoseEngine.swift`: `CVPixelBuffer` captured in a `@Sendable` closure.
- `VoiceFeedbackService.swift`: `@preconcurrency` on delegate conformance has no effect.

## Suggested Next Implementation Steps

1. Run two to four short controlled videos with local capture on.
2. Confirm each session folder contains source video, clips, metadata, and relabel debug.
3. Generate ground truth CSV with `build_ground_truth_template.py`.
4. Label at least 50 strokes.
5. Run `eval_labelers.py`.
6. Read `summary.json` and `failure_modes`.
7. If most failures are `clip_missed_contact`, re-architect candidate/contact generation.
8. If most failures are `type_misclassified_with_contact`, improve prompt/ensemble or start classifier dataset work.
9. If most failures are `contact_timing_error`, improve phase/contact labeling and clip boundaries.
10. Only after that, decide whether to train the lightweight classifier.

