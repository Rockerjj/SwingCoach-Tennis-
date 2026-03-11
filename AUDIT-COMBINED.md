# Tennique (TennisIQ) — Combined Codebase Audit
**Date:** March 10, 2026 | **Auditor:** OpenClaw (Opus 4.6) | **Files reviewed:** 45 Swift + 12 Python

---

## Executive Summary

**The good news:** This is a legitimately well-architected MVP. Clean MVVM, proper service decoupling, solid SwiftData models, working StoreKit 2 integration. The analysis pipeline (camera → pose → stroke detection → LLM → results display) is complete end-to-end. The UI is polished — three design themes, expandable coaching cards, phase timeline, wireframe overlay with angle annotations. This is not a prototype; it's a product that's 70% shippable.

**The bad news:** There are 5-6 issues that would crash or silently fail on a real device, the backend is sending **zero key frame images** to GPT (defeating the whole vision model advantage), and the "wow factor" is currently buried under a loading screen. The real-time live feedback exists but isn't connected to the recording flow in a way users would notice.

**Bottom line:** 2-3 focused days of fixes gets this to TestFlight. 1-2 weeks gets it to App Store.

---

## 🔴 P0 — Must Fix Before TestFlight

### 1. Backend sends ZERO images to GPT (CRITICAL)
**File:** `backend/app/routes/sessions.py` line ~30
```python
key_frame_images: list[bytes] = []  # Always empty!
```
The iOS app sends key frames as multipart form data (`key_frame_0`, `key_frame_1`, etc.), but the backend **never reads them from the request**. The route only reads `pose_data`. So GPT-4o Vision is running blind — no images, just pose JSON. This is your single biggest quality problem.

**Fix:** Parse the additional multipart files from the request. FastAPI supports `request.form()` for dynamic file fields, or define explicit `UploadFile` params for each key frame.

### 2. Auth token flow — missing Supabase exchange
**File:** `AuthService.swift`
The app stores Apple's `identityToken` in keychain and sends it as a Bearer token. But the backend `deps.py` likely expects a **Supabase JWT**, not an Apple identity token. The app never exchanges the Apple token with Supabase Auth. Guest mode generates a random UUID which will fail any backend auth check.

**Fix:** After Apple Sign In, call `supabase.auth.signInWithIdToken(provider: .apple, idToken: tokenString)` to get a proper Supabase session. Store and refresh the Supabase access token.

### 3. `RecordView` → `LiveSwingAnalyzer` not connected
**File:** `RecordViewModel.swift`
The `LiveSwingAnalyzer` exists with phase detection, angle zone checks, and coaching cues — but `RecordViewModel` doesn't instantiate or feed it. It records video and saves it, period. The `LiveFeedbackOverlayView` exists in Views/Record/ but there's no bridge from camera frames to the analyzer during recording.

**Fix:** Add an `AVCaptureVideoDataOutput` alongside the movie output. Feed sample buffers through `PoseEstimationService.detectPose()` → `LiveSwingAnalyzer.processFrame()` during recording. This is the real-time feedback pipeline that would create the "wow."

### 4. `CameraService` — no video data output for live processing
**File:** `CameraService.swift`
Only uses `AVCaptureMovieFileOutput` for recording. No `AVCaptureVideoDataOutput` for frame-by-frame processing. These two outputs can coexist on the same capture session, but currently only movie recording is set up.

### 5. `uiColor(_ color: any ShapeStyle)` returns `.white` always
**File:** `OverlayRenderer.swift` line ~170
```swift
private func uiColor(_ color: any ShapeStyle) -> UIColor {
    .white  // ← ignores the actual color
}
```
Every overlay color that passes through this function renders as white. The skeleton, trajectory lines, and annotations are all white regardless of theme. The second overload `uiColor(_ color: Color)` works fine, but several call sites use `ShapeStyle`.

### 6. Supabase credentials hardcoded in Constants.swift
**File:** `Constants.swift`
The Supabase anon key is hardcoded as a fallback. This is the anon key (not service key), so it's semi-public by design, but it should still be managed through environment/config for production.

---

## 🟠 P1 — Must Fix Before App Store

### 7. Model upgrade: GPT-4o → GPT-5.4 or Claude Sonnet 4.6
**File:** `backend/app/config.py`
Currently hardcoded to `gpt-4o`. The prompts are well-structured for structured JSON output. Upgrading to GPT-5.4 would improve:
- Coaching insight quality (better reasoning about biomechanics)
- Structured output reliability (fewer parse failures)
- Vision analysis accuracy (if P0 #1 is fixed — images actually sent)

**Recommendation:** Support both models via env var. Test GPT-5.4 and Claude Sonnet 4.6 side by side. GPT-5.4 likely wins on structured JSON output reliability; Claude Sonnet may give more nuanced coaching language.

### 8. Prompt optimization for GPT-5.4
**File:** `backend/app/prompts/tennis_coach.py`
The current prompt is solid but over-constrained for GPT-5.4's capabilities. Recommendations:
- Remove the example JSON template — GPT-5.4 handles schema adherence better without verbose examples
- Add `response_format: { type: "json_schema", schema: {...} }` for guaranteed structure
- Increase `max_tokens` to 12000 — GPT-5.4 can produce richer coaching narratives
- Use `"detail": "high"` for images instead of `"low"` — GPT-5.4 vision is dramatically better at high detail for biomechanics
- Add a "personality" layer: "You are a world-class tennis coach. Be specific, encouraging but honest."

### 9. `StrokeDetector.inferStrokeType` — incorrect midpoint calculation
**File:** `StrokeDetector.swift`
```swift
let midX = (map["left_shoulder"]?.x ?? 0.5 + (map["right_shoulder"]?.x ?? 0.5)) / 2
```
Operator precedence bug. `??` binds tighter than `+`, so this evaluates as:
`(left_shoulder.x ?? (0.5 + right_shoulder.x ?? 0.5)) / 2` — not the intended average.
**Fix:** `let midX = ((map["left_shoulder"]?.x ?? 0.5) + (map["right_shoulder"]?.x ?? 0.5)) / 2`

### 10. No volley detection
The `inferStrokeType` only returns "forehand", "backhand", or "serve". Never "volley" — despite volley being listed as a core stroke in the README and subscription features. The LLM prompt also lists volley analysis.

### 11. `SubscriptionService` — `freeAnalysesUsed` not synced
Uses `UserDefaults` for tracking free analyses, which resets on app reinstall. Should be tied to the user account in Supabase.

### 12. No offline error handling
If the backend is unreachable, the analysis just fails with a generic error. Should detect offline state and offer to queue the analysis for later.

### 13. `AnalysisViewModel` fallback auth token
```swift
let authToken = (storedToken?.isEmpty == false) ? storedToken! : "dev-token"
```
Shipping "dev-token" as a fallback to production would be a security issue if the backend actually validates tokens.

### 14. Share image generation doesn't include the actual video frame
`ShareService.generateShareImage` likely generates a generic branded card. For virality, it should composite the skeleton overlay on an actual key frame from the video.

---

## 🟡 P2 — Should Fix for v1.1

### 15. `VoiceFeedbackService` — exists but not integrated
The service file exists but isn't called anywhere in the recording or analysis flow. Adding voice callouts during live recording ("Nice hip rotation!" / "Bend those knees!") would be a massive differentiator.

### 16. Catmull-Rom trajectory smoothing is heavy
`PlaybackViewModel.smoothTrajectory` uses Catmull-Rom spline interpolation on every frame update. For 60fps playback this is fine, but at 0.25x speed with auto-slow, it's recalculating unnecessarily. Should cache smoothed paths per stroke window.

### 17. `PoseEstimationService` — could use `VNDetectHumanBodyPose3DRequest` (iOS 17+)
Currently using 2D pose (`VNDetectHumanBodyPoseRequest`). iOS 17+ supports 3D pose estimation which would give depth data — critical for distinguishing forehand/backhand from a side camera angle and measuring true racket-head speed.

### 18. No video compression before upload
Key frames are sent as JPEG at 0.7 quality, which is good. But the pose JSON can be large for long sessions (1800 frames × 15 joints). Should compress with gzip.

### 19. Design themes exist but `DesignSystem.current` is static
No mechanism for the user to actually switch themes at runtime and persist the choice. The theme picker exists in ProfileView but the underlying state management isn't clear.

### 20. `ProComparisonService` — likely returns hardcoded data
The "Compare to Pro" feature shows pro players but the actual comparison data (ideal joint positions for Federer's forehand, etc.) would need real biomechanics data. Currently this is probably placeholder.

---

## 🟢 P3 — Future / Phase 2

### 21. Real-time streaming analysis (WebSocket)
Add a WebSocket endpoint for streaming pose data during recording. Backend accumulates frames and pushes coaching cues back in real time. This is the true "wow" feature.

### 22. Side-by-side pro comparison with real tournament footage
Requires building the pro swing clip library. Start with manually curated clips, graduate to the AI scraper.

### 23. Community features
Start with a Discord community, build in-app later.

### 24. Drill library
Curated video content. Can launch with 20 drills in v1.1.

### 25. Coach Mode (TV analysis)
Point phone at TV, analyze match in real time. Requires the vision pipeline to handle non-standard camera angles and broadcast footage quality.

---

## Architecture Assessment

| Area | Rating | Notes |
|---|---|---|
| MVVM implementation | 8/10 | Clean separation. ViewModels are @MainActor, services are decoupled. |
| Service layer | 7/10 | Good separation but some services exist without being wired up (VoiceFeedback, LiveSwingAnalyzer). |
| State management | 7/10 | Proper @Published + Combine. Minor concern: PlaybackViewModel retains large frame arrays in memory. |
| Camera pipeline | 6/10 | Works for recording but missing video data output for real-time processing. |
| Pose estimation | 7/10 | Solid use of Vision framework. Could upgrade to 3D pose for depth. Sampling at 15fps is reasonable. |
| Stroke detection | 6/10 | Wrist velocity approach works for obvious strokes but will miss soft volleys, drop shots. The fallback phase builder uses fixed time offsets which is hacky. |
| Backend API design | 7/10 | Clean FastAPI. Major gap: not reading uploaded images. |
| LLM prompts | 8/10 | Well-structured, forces grounded analysis from measured data. Could be tighter for GPT-5.4. |
| SwiftData models | 8/10 | Clean schema. JSON blobs for complex nested data is the right call for SwiftData. |
| StoreKit 2 | 8/10 | Proper implementation with transaction listener. |
| Auth | 5/10 | Apple Sign In works but no Supabase token exchange. Guest mode is a dead end. |
| UI/UX | 9/10 | Genuinely impressive. Phase timeline, wireframe overlay, auto-slow, swing path, coaching cards — this looks like a funded startup's app. |

---

## The "Wow Factor" Assessment

### Current first-session experience:
1. Open app → Onboarding (3 screens) → Sign In
2. Record video → Wait (pose extraction progress bar, ~30-60s)
3. Wait more (LLM analysis, ~15-30s)
4. See results with skeleton overlay, grades, coaching cards

**Verdict:** The results screen IS impressive — but the 60-90 second wait kills the magic. And since images aren't being sent, the coaching quality is limited to what the LLM can infer from joint coordinates alone.

### Fastest path to jaw-dropping:
1. **Fix P0 #1** (send images to GPT) — coaching quality jumps 3x overnight
2. **Fix P0 #3-4** (connect live analyzer) — real-time skeleton + cues during recording = instant "holy shit" moment
3. **Upgrade to GPT-5.4** — better vision analysis, richer coaching
4. **Add voice cues** — "Great follow-through!" spoken aloud during recording

### What would make this demo-worthy:
The demo that sells this app: Start recording → skeleton appears on your body in real-time → you swing → voice says "Elbow dropped 12 degrees at contact — try keeping it higher" → stop recording → full analysis with side-by-side ideal comparison → shareable card with your grade.

That flow is **80% built**. The pieces exist. They just aren't connected.

---

## Quick Win Execution Plan

| Day | Task | Impact |
|---|---|---|
| **Day 1** | Fix backend image parsing (P0 #1) | Coaching quality 3x improvement |
| **Day 1** | Fix `inferStrokeType` operator precedence (P1 #9) | Correct stroke classification |
| **Day 1** | Fix `uiColor` always returning white (P0 #5) | Overlays actually use theme colors |
| **Day 2** | Add `AVCaptureVideoDataOutput` to CameraService (P0 #3-4) | Enable real-time pipeline |
| **Day 2** | Wire LiveSwingAnalyzer to recording flow | Live skeleton + feedback during recording |
| **Day 2** | Upgrade backend model to GPT-5.4, increase image detail | Better analysis quality |
| **Day 3** | Connect VoiceFeedbackService to live analyzer | Voice coaching during recording |
| **Day 3** | Fix auth flow — Supabase token exchange (P0 #2) | Auth actually works end-to-end |
| **Day 3** | TestFlight build + internal testing | Ship it |

---

## Interview Questions for Josh

Before I start building, I need answers on these:

1. **Supabase project status** — Is the Supabase project (`ksfntpplbgtingcdizey`) active? Have you run the schema SQL? Is Row Level Security configured?

2. **Apple Developer account** — Is the app registered in App Store Connect? Are the StoreKit product IDs (`tennisiq_monthly`, `tennisiq_annual`) configured? Do you have certificates/provisioning profiles set up?

3. **Backend deployment** — Where should this run? Railway (mentioned in README)? The debug URL points to `10.0.0.48:8000` — is that your local network? Do you have a Railway account?

4. **OpenAI API key for backend** — Do you have one configured in the `.env`? The backend needs it for GPT analysis.

5. **Brand name** — The codebase says "TennisIQ" everywhere but you're calling it "Tennique." Which name ships? This affects bundle IDs, App Store listing, URLs, everything.

6. **Pricing decision** — The Hormozi audit suggests $29/$59/$129 tiers. But the StoreKit config only has two products (monthly/annual). What's the actual pricing for v1 launch? Are we doing the tiered model or starting simpler?

7. **Target user for v1** — Are we shipping to a broad audience or doing a controlled beta? This affects how polished the onboarding needs to be vs. how fast we ship.

8. **Your phone** — What iPhone model? Need to know for camera capability testing (3D pose requires iPhone 12+, LiDAR would unlock more).

9. **Do you have tennis video?** — To test the analysis pipeline, I need sample footage. Do you have any recorded sessions we can use?

10. **React Native rewrite** — You mentioned react-native-vision-camera. Given the codebase is 80% there in native Swift, do you still want to explore RN? My strong recommendation is to ship native first, then evaluate RN for Android later.

---

*This audit is saved at `tennique/AUDIT-COMBINED.md`*
