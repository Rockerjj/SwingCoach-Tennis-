# Tennis Coach AI Launch Tracker

Last updated: 2026-05-07

## Launch Thesis

Ship the app when it can reliably do three things:

1. Detect the correct stroke type and contact moment from real user video.
2. Give coaching that is specific, safe, short enough to act on, and grounded in measured pose data.
3. Complete analysis without silent fallback, blank cards, missing media, or confusing failure states.

The highest-accuracy architecture should be layered:

- On-device capture: record clean video, extract pose, keyframes, and short stroke clips.
- Pose layer: MediaPipe full/heavy or Apple Vision, selected by measured accuracy and device stability.
- Relabel layer: video-plus-trajectory model corrects stroke type and phase timestamps.
- Coaching layer: best final-response model writes the user-facing analysis from corrected labels and measured angles.

Do not use a general LLM as the first source of truth for biomechanics. Use it to interpret measured evidence and explain it.

## Recommended Model Strategy

### Detection and Phase Labeling

- [ ] Primary bake-off candidates:
  - `mediapipe_gemini` using `gemini-3-flash-preview`, custom video FPS, and MediaPipe trajectory.
  - `mediapipe_gemini` using `gemini-3-pro-preview`, custom video FPS, and MediaPipe trajectory.
  - `mediapipe_sonnet` only as fallback or quality benchmark if latency is acceptable.
  - Pure MediaPipe heuristic as the zero-cost baseline.
- [ ] Do not use GPT-5.5 as the primary stroke detector unless it wins a direct relabeler eval against Gemini video. It has strong reasoning, but the current OpenAI API model docs list image input, not native video input as the core model surface.
- [ ] For Gemini video labeling, set custom video sampling FPS for tennis clips. Default 1 FPS is too coarse for contact timing.
- [ ] Treat relabeler failures as wrong in eval summaries, not as excluded rows.
- [ ] Add a confidence threshold before overwriting iOS labels.

### Final Coaching Analysis

- [ ] Add GPT-5.5 as a challenger for final coaching analysis, not as a replacement for detection.
- [ ] Implement GPT-5.5 through the Responses API with Structured Outputs.
- [ ] Use `reasoning.effort=medium` as the default starting point.
- [ ] Use `text.verbosity=low` or tight prompt constraints for coaching cards.
- [ ] Keep Claude as an active benchmark because the current tool-use implementation already enforces schema well.
- [ ] Pick production default by blind eval, not intuition:
  - Schema completeness.
  - Coaching specificity.
  - Accuracy against corrected pose/phase data.
  - Latency p50/p95.
  - Cost per completed session.
  - User-facing readability.

## P0 Accuracy and Reliability Fixes

- [x] Add `TennisIQ/Resources/pose_landmarker_full.task` to the Xcode Resources build phase.
  - Done when the built `.app` bundle contains `pose_landmarker_full.task`.
- [ ] Decide one production pose default and make code match it.
  - Current mismatch: `PoseEstimationService` defaults to MediaPipe while `AppConstants.FeatureFlags.poseEngine` says Vision.
  - Done when the app logs the active pose engine per analysis and no dead flag exists.
- [ ] Add safe MediaPipe runtime fallback.
  - If MediaPipe model load fails, fall back to Vision and mark `pose_engine="vision_fallback"` in payload metadata.
- [ ] Add pose-engine metadata to `SessionPosePayload`.
  - Include `pose_engine`, `pose_model_version`, `pose_model_asset`, `video_orientation`, `frame_size`, and `processing_fps`.
- [x] Fix backend production dependencies.
  - Add Python deps: `mediapipe`, `opencv-python-headless`.
  - Add system deps in `backend/Dockerfile`: `ffmpeg`.
  - Done when backend container can import `cv2`, import `mediapipe`, and run `ffprobe`.
- [x] Replace dead/old default model IDs.
  - Remove `gemini-2.5-pro-preview-05-06`.
  - Use env-driven defaults and fail loudly when model is unavailable.
- [ ] Make relabeling safe by default.
  - Either default `RELABEL_STROKES=false` until deployment is proven, or keep true only with dependency health checks.
  - Log `relabel_attempted`, `relabel_succeeded`, `primary_labeler`, `fallback_labeler`, and per-stroke confidence.
- [ ] Preserve original labels.
  - Store both iOS label and relabeled output so bad relabeler calls can be audited.
- [x] Add relabeler confidence and validation.
  - Only overwrite when `confidence >= 0.75`, all required phases exist, ordering is valid, and contact is within clip bounds.
- [ ] Pass handedness into labelers.
  - Current MediaPipe heuristic hard-codes right-handed logic.
- [ ] Limit concurrent hosted relabeler calls.
  - Use an async semaphore to avoid provider rate limits on sessions with many strokes.

## P0 Eval Harness Fixes

- [x] Score failures as failures.
  - Summary denominator must include errored and unknown outputs.
- [x] Report coverage.
  - `attempted`, `succeeded`, `unknown`, `errored`, `overwritten`.
- [x] Add confusion matrix by stroke type.
- [x] Add contact-point MAE separately from full phase MAE.
- [ ] Add phase coverage and phase ordering rate.
- [ ] Add p50/p95 latency and p50/p95 cost.
- [ ] Add per-session accuracy so one long session does not dominate.
- [ ] Expand ground truth before final model choice.
  - Minimum: 50 labeled strokes.
  - Target: 100+ labeled strokes.
  - Include forehand, backhand, serve, volley, left-handed strokes, low light, rear/side angles, partial occlusion, indoor/outdoor.
- [ ] Create a frozen launch eval set.
  - No prompt/model tuning against final holdout after it is frozen.

## P1 Codebase Changes

- [ ] Add `OpenAICoachingService` for GPT-5.5.
  - Use Responses API.
  - Use Pydantic JSON schema as Structured Output.
  - Capture input/output/cached token usage.
  - Add provider key such as `openai_gpt55`.
- [ ] Refactor provider names.
  - Avoid hard-coding future/ambiguous model names in comments.
  - Production should use explicit env model IDs.
- [ ] Update pricing table.
  - Add current OpenAI GPT-5.5 pricing.
  - Add Gemini 3 Pro/Flash pricing.
  - Verify Anthropic model IDs and pricing against the account actually used.
- [ ] Add backend health endpoint checks.
  - API keys present.
  - ffmpeg available.
  - MediaPipe model exists.
  - provider model smoke tests optional but useful in staging.
- [ ] Add user-visible graceful failure states.
  - Upload failed.
  - Pose extraction failed.
  - Analysis queued.
  - Provider timeout.
  - No strokes detected.
- [ ] Add analysis job queue before broad launch.
  - Avoid keeping mobile requests open for full LLM latency.
  - Return session status and poll/subscribe for completion.
- [ ] Add retry and idempotency.
  - Re-running analysis for the same session should not duplicate rows.
- [ ] Add analytics events.
  - `record_started`, `record_completed`, `pose_extracted`, `analysis_uploaded`, `analysis_ready`, `analysis_failed`, `share_started`, `paywall_viewed`, `subscription_started`.
- [ ] Add crash reporting.
  - Sentry, Firebase Crashlytics, or another lightweight option.
- [ ] Add privacy-safe payload capture mode.
  - Explicit local/staging only.
  - Never enabled in production.

## P1 Product Quality

- [ ] Make the first analysis feel reliable.
  - Progress stages should reflect actual work: upload, pose, relabel, coaching, saving.
- [ ] Tune coaching card language.
  - Notes should be short, non-numeric, and actionable.
  - Technical angle details can live behind a detail view.
- [ ] Add "why this matters" only where it helps.
  - Avoid long generic coaching prose.
- [ ] Make every recommendation come with a drill.
  - Drill name, reps, focus cue, common mistake.
- [ ] Add session-level top priority.
  - User should know the one thing to work on next.
- [ ] Add review flow for bad analysis.
  - "This is wrong" feedback should capture session ID, stroke ID, expected stroke type, and optional comment.

## P1 TestFlight Checklist

- [ ] Build succeeds from clean checkout.
- [ ] `pod install` path documented.
- [ ] App launches in Debug and Release.
- [ ] Real device camera recording works.
- [ ] Microphone/audio session does not break recording.
- [ ] Analysis completes on Wi-Fi and cellular.
- [ ] No-stroke video produces a helpful result.
- [ ] Short clip, long session, and interrupted upload all behave correctly.
- [ ] Sign in works.
- [ ] Guest flow works or is intentionally disabled.
- [ ] Subscription/paywall configured in StoreKit and App Store Connect.
- [ ] Privacy policy URL live.
- [ ] Terms URL live.
- [ ] Support email live.
- [ ] App Store screenshots complete.
- [ ] App Store description and keywords complete.
- [ ] App privacy nutrition labels complete.
- [ ] TestFlight internal group created.
- [ ] TestFlight external group created.
- [ ] Beta feedback process defined.

## P1 Backend Launch Checklist

- [ ] Production `DEBUG=false`.
- [ ] Debug auth bypass disabled.
- [ ] Supabase service key configured only server-side.
- [ ] RLS policies verified.
- [ ] API rate limits enabled.
- [ ] Request size limits checked for video clips.
- [ ] Provider API keys configured in Railway.
- [ ] Model env vars set in Railway.
- [ ] Database migrations applied.
- [ ] Analysis status transitions tested: processing, analyzing, ready, failed.
- [ ] `analysis_runs` records success and failure.
- [ ] Logs include session ID and provider but no raw private video data.
- [ ] Alerts configured for high failure rate and high latency.

## P2 Launch Readiness Metrics

- [ ] Analysis success rate >= 95 percent on TestFlight sessions.
- [ ] Stroke type accuracy >= 90 percent on frozen eval set.
- [ ] Contact point MAE <= 0.25s on frozen eval set.
- [ ] Phase ordering validity >= 98 percent.
- [ ] Median end-to-end analysis latency <= 90s.
- [ ] P95 end-to-end analysis latency <= 180s.
- [ ] Cost per completed session within launch budget.
- [ ] Crash-free sessions >= 99 percent.
- [ ] Fewer than 5 percent of users mark analysis as wrong.
- [ ] At least 10 external beta users complete 2+ sessions.

## Suggested Order Of Work

1. Fix launch blockers:
   - Bundle MediaPipe model.
   - Add backend MediaPipe/ffmpeg dependencies.
   - Replace dead Gemini preview model.
   - Make relabeling guarded and observable.
2. Repair eval validity:
   - Count failures.
   - Add confidence/coverage metrics.
   - Expand ground truth.
3. Run detection bake-off:
   - MediaPipe heuristic.
   - Gemini 3 Flash plus trajectory.
   - Gemini 3 Pro plus trajectory.
   - Sonnet fallback.
4. Add GPT-5.5 coaching challenger:
   - Responses API.
   - Structured Outputs.
   - Medium reasoning.
   - Low verbosity.
5. Run blind coaching bake-off:
   - Current Claude provider.
   - GPT-5.5.
   - Gemini only if schema reliability is fixed.
6. Ship TestFlight:
   - Internal first.
   - 10-25 external testers.
   - Freeze launch eval set.
7. Submit App Store build:
   - Only after accuracy, latency, crash, and feedback thresholds are met.

## Decision Log

- 2026-05-07: GPT-5.5 should be evaluated for final coaching analysis, not used as the first stroke detector.
- 2026-05-07: Detection should be won by evals over video-plus-trajectory labelers.
- 2026-05-07: Relabeler must be observable and confidence-gated before production default-on.
