# TennisIQ / Tennique — Codebase Audit

**Auditor:** Senior iOS/Swift Engineer & Product Architect  
**Date:** 2026-03-10  
**Codebase Version:** As of CODEBASE-DUMP.md

---

## 1. File-by-File Quality

### iOS — App Layer

| File | Purpose | Score | Issues |
|------|---------|-------|--------|
| **TennisIQApp.swift** | (not in dump — assumed entry point) | N/A | Not provided; presumably standard `@main` App struct |
| **ContentView / MainTabView** | (not in dump) | N/A | Not provided; the root navigation is missing from dump |

### iOS — Models (inferred from usage in Views/Services)

| File | Purpose | Score | Issues |
|------|---------|-------|--------|
| **SessionModel** (SwiftData) | Core session persistence | 7/10 | Used correctly as `@Model`. `status` is a raw-value enum stored by SwiftData — works but enum conformance not shown. `poseFramesJSON` stored as `Data?` (blob in SwiftData) — acceptable for MVP, but querying individual frames is impossible. `thumbnailData` as `Data?` in the model risks bloating SwiftData store. |
| **StrokeAnalysisModel** (SwiftData) | Per-stroke analysis results | 6/10 | Heavy JSON blob storage (`mechanicsJSON`, `overlayInstructionsJSON`, `phaseBreakdownJSON`, etc.). Every property access requires JSON decoding — no caching visible. Computed properties presumably decode each time. Relationship to `SessionModel` via `session` backlink — fine. |
| **ProgressSnapshotModel** (SwiftData) | Progress tracking | 7/10 | Clean. `trendingDirection` stored as string enum. `@Query` predicates in `ProgressDashboardView` use raw string comparisons — fragile if enum raw values change. |
| **Data Models** (FramePoseData, JointData, etc.) | Pose/joint types shared between services | 7/10 | Clean Codable structs. `JointMapping`, `Handedness`, `SwingPhase`, `StrokeType`, `ZoneStatus` — well-structured enums. Dead code: `midX` calculation in `inferStrokeType` has operator precedence bug (see below). |

### iOS — Services

| File | Purpose | Score | Issues |
|------|---------|-------|--------|
| **AnalysisAPIService** | HTTP client for backend | 6/10 | Multipart upload is hand-rolled — works but brittle. Key frames sent as JPEG parts with timestamps as filenames. **Critical:** `uploadSession` sends images correctly, BUT the backend `analyze_session` endpoint reads ONLY `pose_data` as a single `UploadFile`. The endpoint signature is `pose_data: UploadFile = File(...)` — it **never reads the key frame images from the multipart form**. The images are uploaded but silently discarded on the server. See Backend section. Missing retry logic, no timeout configuration. |
| **AnalyticsService** | Event tracking + rating prompts | 7/10 | Logger-only analytics — no actual analytics backend (no Firebase, Mixpanel, etc.). Fine for MVP. `requestAppStoreRating()` accesses `UIApplication.shared.connectedScenes` on `@MainActor` — correct. |
| **AuthService** | Apple Sign In + guest mode | 6/10 | **No Supabase auth exchange.** Apple Sign In captures the `identityToken` and stores it in Keychain, but never sends it to Supabase for JWT exchange. The app just stores the Apple user ID locally and calls itself "authenticated." The backend uses a completely separate auth system via bearer token. Guest mode generates a random UUID — fine but means guest data is lost on reinstall. No token refresh logic. |
| **CameraService** | AVFoundation camera management | 7/10 | Solid camera setup. 60fps configuration with fallback. Audio session configured for `.playAndRecord`. `AVCaptureMovieFileOutput` with max duration. Timer updates on 0.1s interval via `DispatchQueue.main.async` from a non-main timer — **potential Sendable violation** in Swift 6 strict concurrency (timer callback captures `self` across isolation boundaries). `teardown()` calls `stopRecording()` then `captureSession?.stopRunning()` on main thread — `stopRunning()` is synchronous and blocks; should be dispatched to background. |
| **FeedbackService** | Submit user feedback | 5/10 | Bare-bones. Failed requests saved to UserDefaults as raw JSON data — but **never retried** on next launch. No queue processing. Fire-and-forget with silent failure. |
| **LiveSwingAnalyzer** | Real-time swing phase detection | 4/10 | **Largely disconnected from camera pipeline.** `RecordView` creates it as a `@StateObject` but never feeds it frames. The camera records via `AVCaptureMovieFileOutput` which doesn't provide per-frame callbacks. To actually work, would need `AVCaptureVideoDataOutput` running simultaneously, plus Vision pose estimation in real-time. Currently **pure dead code during recording** — the UI shows the overlay but `processFrame()` is never called. The phase detection logic itself is reasonable (wrist velocity-based), but the zone angles are hardcoded without calibration and the `computeAngle` function for named zones like "hip_lead" just falls through to `shoulderRotationAngle` — incorrect mapping. |
| **OverlayRenderer** | Draw skeleton/annotations on UIImage | 6/10 | `UIGraphicsBeginImageContextWithOptions` is legacy — should use `UIGraphicsImageRenderer` for modern API. `uiColor(_ color: any ShapeStyle) -> UIColor` returns `.white` always — **completely broken**. This means all ShapeStyle-based theme colors render as white. The `uiColor(_ color: Color)` overload works, but the wrong one gets called for protocol-typed theme properties. |
| **PoseEstimationService** | Apple Vision body pose extraction | 7/10 | Core pipeline works: `AVAssetReader` → `VNDetectHumanBodyPoseRequest` → `FramePoseData`. Good frame sampling (60fps → 15fps). Key frame extraction uses wrist velocity peaks — reasonable heuristic. **Issue:** `detectPose` is called with `async throws` but `VNImageRequestHandler.perform()` is synchronous and runs on the calling thread — in `extractPoses`, this blocks the cooperative thread pool since it's called from an `async` context without dispatching to the processing queue (`processingQueue` is declared but never used!). On a 30-second video at 15fps, that's 450 synchronous Vision calls blocking async threads. **Performance bug.** Should dispatch to `processingQueue`. Also uses 2D pose only (`VNDetectHumanBodyPoseRequest`) — iOS 17+ supports `VNDetectHumanBodyPose3DRequest` which would give depth information for better angle measurement. |
| **ProComparisonService** | Pro player pose data | 3/10 | **Completely stubbed.** `getProPoseData` tries to load JSON from `Bundle.main` subdirectory `ProPoseData/` — these files don't exist. The entire "Compare to Pro" feature is a hollow UI with no data. |
| **ShareService** | Generate share images | 6/10 | Nice share card generation with skeleton overlay, grade badge, watermark. `toCanvas` function **swaps x and y coordinates** — intentional? `joint.y * canvasSize.width` for x and `joint.x * canvasSize.height` for y. This implies Vision coordinates are in a rotated space (which they are for portrait video), but this should be documented. |
| **StrokeDetector** | Detect strokes from pose frames | 7/10 | Best-implemented service. Velocity-based peak detection with dynamic thresholds, smoothing, phase scanning. Fallback phases when temporal ordering fails. `inferStrokeType` has a **bug**: `let midX = (map["left_shoulder"]?.x ?? 0.5 + (map["right_shoulder"]?.x ?? 0.5)) / 2` — operator precedence means this computes `0.5 + right_shoulder.x` when `left_shoulder` is nil, not the average. Should be `((map["left_shoulder"]?.x ?? 0.5) + (map["right_shoulder"]?.x ?? 0.5)) / 2`. |
| **SubscriptionService** | StoreKit 2 | 7/10 | Clean StoreKit 2 implementation. Product loading, purchase flow, transaction listener, entitlement checking. `listenForTransactions()` uses `Task.detached` but accesses `self` without `@Sendable` closure — Swift 6 concurrency warning. `checkVerified` is `nonisolated` — correct for calling from detached task. `freeAnalysesUsed` tracked in UserDefaults — works but easily spoofed by deleting app data. |
| **VoiceFeedbackService** | Text-to-speech coaching cues | 6/10 | Works as standalone, but like `LiveSwingAnalyzer`, **never receives actual input during recording**. The `RecordView` creates it but nothing calls `speak()`. Priority queue with cooldown is well-designed. Uses `AVSpeechSynthesizer` which conflicts with `AVAudioSession` configured for video recording — **will crash or produce no audio** if called during active recording. |

### iOS — ViewModels

| File | Purpose | Score | Issues |
|------|---------|-------|--------|
| **AnalysisViewModel** | Orchestrates pose extraction → API call → save results | 7/10 | Good flow: extract poses → upload → apply results. Auth token logic: falls back to "dev-token" if no Apple token — will work with debug backend. `resolveVideoURL` correctly looks in Documents directory. `applyResults` maps API response to SwiftData models. **Memory concern:** `ExtractionResult` holds all `UIImage` key frames in memory simultaneously (up to 20 full-res images). For a 30-min video, this could be significant. |
| **RecordViewModel** | Camera recording + session save | 7/10 | Clean. Saves video to Documents directory, creates `SessionModel`. Timer via Combine `Timer.publish`. **Issue:** `startRecording` accepts a `ModelContext` and holds it as `modelContext` instance var — if the view is re-created, the old context reference may be stale. |

### iOS — Views

| File | Purpose | Score | Issues |
|------|---------|-------|--------|
| **OnboardingView** | 3-page intro | 8/10 | Clean, well-structured. Good use of `TabView` with page style. |
| **SignInView** | Apple Sign In + guest | 7/10 | Clean. Missing loading state during sign-in. |
| **RecordView** | Camera + recording | 7/10 | Good positioning guide, live mode toggle, timer overlay. **Issue:** `CameraPreviewRepresentable` creates a new `CameraPreviewUIView` each time but `previewLayer` is set in `updateUIView` — this works but the old sublayer isn't explicitly removed (handled by `didSet` on `previewLayer`). Live feedback overlay is shown when `liveModeEnabled && viewModel.isRecording` but as noted, no frames are fed to `LiveSwingAnalyzer`. |
| **AnalysisResultsView** | Main results hero screen | 7/10 | Complex but well-decomposed into sub-views. `PlaybackViewModel` is solid — binary search for nearest frame, Catmull-Rom trajectory smoothing, auto-slow during stroke windows. **Issue:** `init(session:)` creates `PlaybackViewModel` with `url ?? URL(string: "about:blank")!` — if video is missing, `AVPlayer` will silently fail but the UI may show a black player with controls. `containerRelativeFrame` requires iOS 17+ — consistent with deployment target. |
| **SessionsListView** | Session list | 7/10 | Clean. "Retry Failed" batch operation is a nice touch. `@Query` with `sort` works correctly. |
| **ProgressDashboardView** | Progress charts | 7/10 | `@Query` with `#Predicate` filter on raw value string — fragile. Custom line chart using `Canvas` — works but Swift Charts would be cleaner (iOS 16+). |
| **ProfileView** | Settings/prefs | 7/10 | Complete: skill level, handedness, theme picker, subscription card, legal links. Theme switching via `DesignSystem.shared.setTheme()` — runtime theme changes may not propagate to all views without `@Published` observation chain. |
| **Component Views** | Various UI components | 8/10 | Well-structured, good separation. `PhaseTimelineView`, `PhaseDetailCard`, `CoachingCard`, `WireframeOverlayView` — all clean. `SwingPathOverlayView` has nice Catmull-Rom resampling. |

### iOS — Design System

Not shown in dump but referenced extensively. `DesignSystem.current`, `AppTheme` protocol, `CourtVisionTheme`, `GrandSlamTheme`, `RallyTheme`, `AppFont`, `Spacing`, `Radius` — appears well-organized from usage patterns.

### Backend — Python

| File | Purpose | Score | Issues |
|------|---------|-------|--------|
| **main.py** | FastAPI app + middleware | 7/10 | Clean. CORS `allow_origins=["*"]` — too permissive for production, should restrict to app bundle. Docs disabled in non-debug — good. |
| **config.py** | Settings via pydantic-settings | 7/10 | Clean. `.env` file support. |
| **models.py** | Pydantic request/response models | 8/10 | Comprehensive, well-typed. Field aliases for camelCase ↔ snake_case. All response types properly defined. |
| **routes/deps.py** | Auth + Supabase dependencies | 5/10 | **Security issue:** Debug mode accepts ANY bearer token and returns `"dev-user-001"`. If `debug=True` leaks to production, all requests authenticate as the same user. `get_current_user_id` uses `python-jose` JWT decode with Supabase anon key — but the iOS app never does the Supabase auth exchange, so this path is untested. |
| **routes/sessions.py** | `/sessions/analyze` endpoint | 4/10 | **CRITICAL BUG: Key frame images are never received.** The endpoint signature is `pose_data: UploadFile = File(...)` — a single file upload. The iOS client sends multipart with `pose_json` + multiple `key_frame_N` parts, but FastAPI only reads `pose_data`. There's no parameter for key frame files. `key_frame_images: list[bytes] = []` is hardcoded empty. **The LLM never sees any images.** This means GPT-4o Vision is running in text-only mode — it gets angle measurements and timestamps but never sees the actual video frames. This is the single biggest bug in the codebase. |
| **routes/progress.py** | Progress endpoint | 7/10 | Clean delegation to `ProgressCalculator`. |
| **routes/feedback.py** | Feedback endpoint | 7/10 | Simple insert to Supabase. Fine. |
| **routes/users.py** | User profile CRUD | 6/10 | Basic. No input validation beyond Pydantic. |
| **services/llm_coaching.py** | GPT-4o Vision integration | 6/10 | The `analyze_session` method correctly handles image encoding and multimodal content construction — **but it never receives images** because the route doesn't extract them. The image processing code is correct but dead. `_resize_image` to 512px with JPEG 75% — good for token efficiency. `max_tokens=8000` — adequate for the response schema. `temperature=0.3` — reasonable for structured output. `response_format={"type": "json_object"}` — good. |
| **services/progress_calculator.py** | Score aggregation | 6/10 | `update_progress` and `get_progress` work but use synchronous Supabase client in `async` functions — won't actually run concurrently. `weakest = min(scores, key=scores.get)` — `scores.get` on a dict doesn't do what's intended; should be `key=lambda k: scores[k]` or just `key=scores.get` (actually `dict.get` works as a callable here since `scores.get("forehand")` returns the value — this is actually fine). |
| **prompts/tennis_coach.py** | System prompt + template | 7/10 | Well-structured prompt with scoring guidelines, ideal ranges, JSON schema. `build_detected_strokes_summary` formats the measured angles nicely. **Issue:** `ANALYSIS_PROMPT_TEMPLATE` uses `{dominant_side}` variable but it's not present in the template string — `format()` call in `llm_coaching.py` passes it as a kwarg but the template doesn't use it. Not a crash, just unused. |

---

## 2. Architecture Assessment

### MVVM Implementation: 6/10
- ViewModels exist for `AnalysisViewModel` and `RecordViewModel` but many views hold their own state and business logic directly (e.g., `SessionsListView` has `retryFailedSessions()` with direct SwiftData manipulation).
- Services are singletons (`AnalyticsService.shared`, `FeedbackService.shared`, `ShareService.shared`) mixed with regular instances — inconsistent DI pattern.
- No dependency injection container or protocol-based abstractions for testability.

### Service Layer Decoupling: 5/10
- Services reference `AppConstants` directly — hardcoded configuration.
- `AnalysisAPIService` is tightly coupled to the URL scheme and multipart format.
- No protocol abstractions for services — can't mock for testing.

### State Management: 6/10
- Race conditions: `CameraService.startRecording` stores `completionHandler` as an instance variable — if `startRecording` is called twice before the first completes, the first handler is lost.
- Memory: `ExtractionResult` holds up to 20 full-resolution `UIImage` objects simultaneously. For 1080p frames, that's ~150MB+ in memory.
- `LiveSwingAnalyzer.frameHistory` accumulates frames with `maxHistory = 15` — fine but the whole system is disconnected.

### Camera Pipeline: 6/10
- 60fps capture → 15fps processing via `AVAssetReader` post-recording — this is **offline** processing, not real-time.
- For real-time, would need `AVCaptureVideoDataOutput` running alongside `AVCaptureMovieFileOutput` — currently not implemented.
- The current approach is correct for the MVP (record → analyze after), but the "Live" toggle in the UI implies real-time capability that doesn't exist.

### Apple Vision Pose Estimation: 6/10
- Uses `VNDetectHumanBodyPoseRequest` (2D) — works but loses depth information.
- iOS 17+ supports `VNDetectHumanBodyPose3DRequest` which would dramatically improve angle measurement accuracy (elbow angles, knee bends, shoulder rotation all benefit from Z-axis).
- The deployment target is iOS 17.0, so 3D pose is available and should be used.
- Vision processing is synchronous on async thread (performance bug described above).

### StrokeDetector: 7/10
- Wrist velocity approach is reasonable for MVP. It correctly identifies high-velocity peaks as contact points and scans backward/forward for phases.
- Weaknesses: Single-wrist tracking can't distinguish between body movement and actual strokes. A player walking across the court could trigger false positives.
- The dynamic threshold (`max(velocityThreshold, avgVelocity * 2.0)`) helps filter noise but may miss soft volleys.
- Phase detection timing relies on velocity profiles that may not generalize across skill levels.

### LiveSwingAnalyzer: 3/10
- **Not connected.** The RecordView doesn't feed frames to it. Even if it were connected, it would need the camera to output sample buffers for real-time processing, which the current `AVCaptureMovieFileOutput`-only setup doesn't provide.
- The angle zone logic is interesting but untested against real data.
- Verdict: **Gimmicky in current state.** The UI looks impressive (live phase pips, form grade ring, floating cues) but it's all driving on zero data.

---

## 3. Ship-Readiness Assessment

### What Works End-to-End ✅
1. Camera recording → save video to documents → create session in SwiftData
2. Pose extraction from recorded video (offline, post-recording)
3. Stroke detection from pose data
4. Upload pose JSON to backend → GPT analysis → receive structured coaching JSON
5. Display analysis results with skeleton overlay, phase breakdown, coaching cards
6. Session list, navigation, basic app flow
7. Onboarding flow
8. Profile/settings with theme switching
9. Guest sign-in (bypass auth entirely)
10. StoreKit 2 product loading and purchase flow (if products are configured in ASC)

### What's Stubbed/Placeholder 🟡
1. **Pro Comparison** — UI exists, no actual pro pose data files
2. **Live swing feedback** — UI exists, not connected to camera pipeline
3. **Voice feedback** — Service exists, never invoked during recording
4. **Progress dashboard** — UI works but depends on Supabase data that may not exist for new users
5. **Analytics** — Logger only, no actual analytics service
6. **Feedback retry** — Saves failed feedback to UserDefaults but never retries

### What Would Crash on Device 🔴
1. **OverlayRenderer `uiColor(_ color: any ShapeStyle)`** returns `.white` always — won't crash but renders incorrectly. When `ShapeStyle` protocol-typed properties are passed, all theme colors become white.
2. **`VoiceFeedbackService.speak()` during recording** — if somehow triggered, `AVSpeechSynthesizer` will conflict with the active `AVAudioSession` configured for video recording.
3. **PlaybackViewModel with `about:blank` URL** — `AVPlayer` will fail silently, but tapping play/pause on a nil video may cause unexpected states.
4. **`ProgressDashboardView` `@Query` with `#Predicate` on `status.rawValue`** — If `SessionStatus` enum doesn't have `.rawValue` accessible this way in the `#Predicate` macro, this will crash at runtime. SwiftData `#Predicate` has limited expression support.

### What Blocks TestFlight 🚫
1. **Supabase anon key is hardcoded in Constants.swift** — this is the real key, visible in source. Not a blocker per se, but a security risk (anon key is designed to be public, but still).
2. **Backend URL points to `api.tennisiq.com`** — needs to be a running server. Debug URL points to local IP `10.0.0.48:8000`.
3. **No App Store Connect setup** — `appStoreID` is empty string, subscription product IDs need to be registered.
4. **Entitlements file** referenced but not shown — needs Sign in with Apple + In-App Purchase capabilities.
5. **No `ProPoseData/` bundle resources** — the app will work without them (comparison feature just shows empty), but it's a dead feature.
6. **No privacy manifest** (`PrivacyInfo.xcprivacy`) — required by Apple since Spring 2024.

### Auth Flow: 3/10
- Apple Sign In captures credential and stores in Keychain — works.
- **Never exchanges Apple identity token with Supabase** — the backend auth expects a JWT but the app sends either the raw Apple token or "dev-token".
- In debug mode, backend accepts anything — so it "works" but is completely insecure.
- In production mode, `python-jose` JWT decode will fail on Apple's identity token (which is a JWT signed by Apple, not by Supabase).
- **The entire auth pipeline is broken for production.**

### StoreKit 2: 7/10
- Implementation is correct: `Product.products(for:)`, `product.purchase()`, `Transaction.currentEntitlements`, `Transaction.updates`.
- Missing: receipt validation on server. The app trusts the client-side entitlement check — vulnerable to jailbreak-based piracy.
- `freeAnalysesUsed` in UserDefaults is trivially reset by deleting app data.
- Product IDs `tennisiq_monthly` and `tennisiq_annual` need to be registered in App Store Connect.

### SwiftData: 6/10
- Models are straightforward. Relationships work (`StrokeAnalysisModel.session` ↔ `SessionModel.strokeAnalyses`).
- Heavy JSON blob pattern (encoding/decoding on every access) is a performance concern with many sessions.
- `@Query` with `#Predicate` using raw value string comparison is fragile.
- No migration strategy defined — first schema change will require manual migration.

---

## 4. Backend Deep Dive

### 🚨 Are Key Frame Images Actually Being Sent to GPT?

**NO.** This is the critical finding.

**iOS Side (AnalysisAPIService.uploadSession):**
```swift
// Sends multipart form with:
// - "pose_json" (JSON file)
// - "key_frame_0", "key_frame_1", ... (JPEG images)
```

**Backend Side (routes/sessions.py):**
```python
@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_session(
    pose_data: UploadFile = File(...),  # ← Only reads ONE file
    ...
):
    pose_bytes = await pose_data.read()
    key_frame_images: list[bytes] = []  # ← ALWAYS EMPTY
    # ...
    result = await coaching.analyze_session(pose_payload, key_frame_images)
    #                                                     ^^^^^^^^^^^^^^ empty list
```

The FastAPI endpoint only declares one `UploadFile` parameter (`pose_data`). The iOS client sends images as additional multipart parts, but FastAPI ignores them because there's no parameter to receive them.

**Fix required:**
```python
@router.post("/analyze", response_model=AnalysisResponse)
async def analyze_session(
    pose_data: UploadFile = File(...),
    key_frames: list[UploadFile] = File(default=[]),
    user_id: str = Depends(get_current_user_id),
    supabase: Optional[Client] = Depends(get_supabase),
):
    # ... read pose_data as before ...
    key_frame_images = [await f.read() for f in key_frames]
```

And the iOS multipart field name should match: currently sends `key_frame_0`, `key_frame_1` — needs to be `key_frames` (repeated field name) for FastAPI's `list[UploadFile]`.

### Prompt Quality: 6/10
**Strengths:**
- Clear scoring guidelines with angle deviation ranges
- Explicit instruction to use measured values, not fabricate
- JSON schema example is comprehensive
- `build_detected_strokes_summary` formats the data well

**Weaknesses:**
- The prompt asks GPT to evaluate angles but without images, it's just rubber-stamping the measured values against hardcoded ideal ranges — no visual context
- "Verified sources" will be hallucinated — GPT will invent plausible-sounding references
- The prompt doesn't specify which tennis teaching methodology to follow
- No few-shot examples — the JSON template is good but a complete example would improve consistency

### Optimizing for Claude Sonnet 4.6 / Opus 4.6

1. **Structured output:** Replace `response_format={"type": "json_object"}` with Claude's tool use / structured output. Use a Pydantic model as the output schema directly — Claude handles this natively and more reliably than free-form JSON generation.

2. **System prompt:** Claude responds better to clear role definition without the "CRITICAL RULES" shouting style. Rewrite as:
```
You are an elite tennis biomechanics analyst. Your analysis must be grounded in the measured joint angles provided — never fabricate measurements.
```

3. **Prompt structure:** Claude handles long, well-structured prompts better than GPT. Move the JSON schema to a tool definition rather than embedding it in the prompt. Use XML tags for data sections:
```xml
<detected_strokes>
...
</detected_strokes>

<scoring_guidelines>
...
</scoring_guidelines>
```

4. **Images:** Claude Opus/Sonnet have excellent vision capabilities. When images are actually sent (after fixing the bug), Claude will provide more grounded analysis than text-only.

5. **Temperature:** Claude's default sampling is well-calibrated at 0.3–0.5. Keep at 0.3 for structured output.

6. **Token budget:** Claude's output is generally more concise than GPT-4o. 8000 max tokens is fine but could likely be reduced to 6000.

### Security Issues
1. **Debug mode bypass:** If `debug=True` in production, all auth is bypassed.
2. **CORS `allow_origins=["*"]`** — should be restricted to the app's domain.
3. **Supabase service key** in backend config — make sure it's in `.env`, not committed.
4. **No rate limiting** on the `/analyze` endpoint — GPT-4o calls cost money; one malicious user could run up the bill.
5. **No input validation on pose data size** — a giant payload could OOM the server.
6. **`python-jose` is unmaintained** — consider switching to `PyJWT`.

---

## 5. "Wow Factor" Assessment

### Current First-Session Experience: 4/10

**The journey:**
1. Open app → 3-screen onboarding (generic, no video demos) → Sign In screen
2. Guest sign-in → Main tab view (Sessions empty, Progress empty)
3. Tap Record → Camera preview with positioning guide
4. Record 30 seconds of tennis → "Session Saved!" screen
5. Navigate to Sessions → Tap session → Loading screen ("Extracting Poses..." then "AI Coach Analyzing...")
6. Wait 30-60 seconds → Results appear with skeleton overlay, grades, phase breakdown

**What kills the wow:**
- The 30-60 second wait between recording and results is a momentum killer
- No visual feedback during recording (live mode is fake)
- The skeleton overlay only appears in the results screen, not during recording
- Without images sent to GPT, the coaching feedback is generic angle-based analysis — not visually grounded
- Empty progress and comparison features on first use

### Fastest Path to Jaw-Dropping First Analysis

1. **Fix the image bug** (P0). With actual video frames going to GPT-4o Vision, the coaching feedback becomes visually specific: "I can see your racket dropping below your wrist at contact" vs. "Your elbow angle of 142° is below ideal." This alone transforms the perceived intelligence of the app.

2. **Pre-compute a sample analysis** — bundle a demo session with pre-computed results so users see the full experience immediately in onboarding, before they even record.

3. **Show skeleton overlay during the loading phase** — while waiting for GPT, show the extracted poses playing back with the skeleton overlay. This demonstrates the technology and keeps users engaged during the wait.

4. **Reduce latency** — start pose extraction while the user reviews the "Session Saved" screen. Don't wait for them to tap into the session.

### Real-Time Feedback During Recording: 1/10
- The UI framework exists (phase pips, form grade ring, floating cues, voice feedback service)
- **None of it is connected.** Zero real-time data flows during recording.
- To make this work: add `AVCaptureVideoDataOutput`, run Vision on every Nth frame, feed to `LiveSwingAnalyzer`
- This is a 2-3 day engineering effort but would be a game-changer for the demo

### What Would Make This Demo-Worthy
1. Fix image sending (1 hour fix)
2. Real-time skeleton overlay during recording (2-3 days)
3. Instant feedback on first stroke detected: haptic + voice "Nice forehand!" (1 day, requires #2)
4. Side-by-side replay with skeleton + coaching annotations (already built, just needs real data)
5. One-tap share card to Instagram stories (mostly built)

---

## 6. Prioritized Punch List

### P0: Must Fix Before TestFlight (crashes, broken flows)

| # | Issue | File(s) | Effort |
|---|-------|---------|--------|
| 1 | **Backend doesn't receive key frame images — GPT runs text-only** | `backend/app/routes/sessions.py`, `AnalysisAPIService.swift` | 2 hours |
| 2 | **PoseEstimationService runs Vision synchronously on async thread — blocks thread pool, likely hangs on long videos** | `PoseEstimationService.swift` | 1 hour |
| 3 | **OverlayRenderer `uiColor(any ShapeStyle)` always returns white** | `OverlayRenderer.swift` | 30 min |
| 4 | **Auth flow is completely broken for production** — Apple token never exchanged with Supabase | `AuthService.swift`, `routes/deps.py` | 1 day |
| 5 | **`@Query` `#Predicate` on `status.rawValue == "ready"` may crash** — test on device | `ProgressDashboardView.swift` | 1 hour |
| 6 | **Add privacy manifest** (`PrivacyInfo.xcprivacy`) — Apple rejects without it | New file | 30 min |
| 7 | **StrokeDetector `midX` operator precedence bug** — incorrect forehand/backhand classification | `StrokeDetector.swift` | 15 min |
| 8 | **Backend debug mode accepts any auth token** — ensure `debug=False` in production config | `config.py`, deployment | 15 min |
| 9 | **`CameraService` `stopRunning()` on main thread** — blocks UI during teardown | `CameraService.swift` | 30 min |

### P1: Must Fix Before App Store (UX, polish)

| # | Issue | File(s) | Effort |
|---|-------|---------|--------|
| 10 | **Start pose extraction immediately after recording** — don't wait for user to tap session | `RecordViewModel.swift`, `AnalysisViewModel.swift` | 4 hours |
| 11 | **Show skeleton playback during "AI Analyzing" wait** | `AnalysisResultsView.swift` | 4 hours |
| 12 | **Add loading/error states to sign-in flow** | `SignInView.swift` | 2 hours |
| 13 | **Restrict CORS origins** | `main.py` | 15 min |
| 14 | **Add rate limiting to /analyze endpoint** | `main.py` | 2 hours |
| 15 | **Bundle a demo analysis** for onboarding wow moment | New asset + onboarding flow | 1 day |
| 16 | **Fix theme color propagation** — ensure runtime theme changes update all views | Design system | 4 hours |
| 17 | **Handle video deletion** — if user deletes video file, show graceful degradation | `AnalysisResultsView.swift` | 2 hours |
| 18 | **Add retry logic to AnalysisAPIService** with exponential backoff | `AnalysisAPIService.swift` | 3 hours |
| 19 | **Upgrade to VNDetectHumanBodyPose3DRequest** for better angle accuracy (iOS 17+) | `PoseEstimationService.swift` | 1 day |

### P2: Should Fix for v1.1

| # | Issue | File(s) | Effort |
|---|-------|---------|--------|
| 20 | **Connect LiveSwingAnalyzer** — add `AVCaptureVideoDataOutput`, real-time Vision, feed to analyzer | `CameraService.swift`, `RecordView.swift` | 3 days |
| 21 | **Connect VoiceFeedbackService** to LiveSwingAnalyzer output | `RecordView.swift` | 4 hours |
| 22 | **Build real pro comparison data** — capture/license pro pose data | `ProComparisonService.swift` | 1 week |
| 23 | **Server-side receipt validation** for StoreKit purchases | Backend new endpoint | 2 days |
| 24 | **SwiftData migration strategy** | New migration code | 1 day |
| 25 | **Replace UserDefaults analytics with proper analytics SDK** (Mixpanel/PostHog) | `AnalyticsService.swift` | 1 day |
| 26 | **Implement Supabase auth exchange** properly (Apple Sign In → Supabase JWT) | `AuthService.swift`, backend | 2 days |
| 27 | **Memory optimization** — stream key frame images to disk instead of holding in memory | `PoseEstimationService.swift` | 4 hours |
| 28 | **Retry failed feedback submissions** on app launch | `FeedbackService.swift` | 2 hours |
| 29 | **Migrate from `python-jose` to `PyJWT`** | Backend deps | 2 hours |

### P3: Future Features

| # | Feature | Effort |
|---|---------|--------|
| 30 | Multi-camera angle support | 2 weeks |
| 31 | Real-time AR overlay using ARKit | 2 weeks |
| 32 | Session video trimming before analysis | 1 week |
| 33 | Coach marketplace / human review | 4 weeks |
| 34 | Android app | 8 weeks |
| 35 | Social features (share progress, challenges) | 2 weeks |
| 36 | Drill library with video demonstrations | 2 weeks |
| 37 | Apple Watch companion (heart rate + movement) | 1 week |
| 38 | Offline analysis mode (on-device LLM) | 2 weeks |

---

## Summary

**What you've built is impressive in scope** — the end-to-end pipeline from camera to AI coaching to visual overlay is real architecture, not a prototype. The UI is polished. The design system with three themes is well-executed. The coaching card UI with phase breakdown, mechanics scoring, and verified sources is exactly what a user would want to see.

**The fatal flaw is the image bug.** GPT-4o Vision is being called without images. Fix that one thing and the analysis quality jumps dramatically. Everything else is polish.

**The second biggest gap is the fake "Live" mode.** The UI promises real-time feedback but delivers nothing. Either connect it or remove it — shipping a feature that visibly does nothing destroys trust.

**TestFlight is 1-2 days away** if you fix P0 items 1, 2, 7, 8 and accept that auth runs in debug mode for now. App Store is maybe 2 weeks of focused work on P0 + P1.

The codebase is well-organized, the patterns are consistent, and the product vision is clear. This is shippable with focused execution.
