# Tennique — Unified Triage & Build Plan
**Date:** March 10, 2026 | **Sources:** Opus 4.6 Audit + Combined Audit + Josh's Feature Vision

---

## How to Read This

Every finding is tagged with who caught it:
- 🟣 = Opus 4.6 only
- 🔵 = My audit only  
- 🟢 = Both audits agreed (highest confidence)

---

## TIER 0: CRITICAL — Ship Blockers

### 1. 🟢 Backend Never Sends Images to GPT
**Impact:** GPT-4o Vision runs text-only. Coaching quality is 30% of what it could be.
**Files:** `backend/app/routes/sessions.py`, `AnalysisAPIService.swift`
**Fix:** Add `key_frames: list[UploadFile]` param to FastAPI endpoint. Align iOS multipart field names.
**Effort:** 2 hours
**Why it matters for Josh's vision:** Side-by-side pro compare, coach mode, and the "wow" demo all depend on vision analysis actually working.

### 2. 🟢 LiveSwingAnalyzer Is Completely Disconnected  
**Impact:** "Live Mode" toggle in RecordView is fake. UI shows phase pips and form grade but processes zero frames.
**Files:** `CameraService.swift`, `RecordView.swift`, `LiveSwingAnalyzer.swift`
**Fix:** Add `AVCaptureVideoDataOutput` alongside movie output. Feed frames through Vision → LiveSwingAnalyzer during recording.
**Effort:** 2-3 days
**Why it matters:** This IS the wow factor. Real-time skeleton + coaching cues during recording is what separates Tennique from every competitor.

### 3. 🟢 Auth Flow Broken for Production
**Impact:** Apple Sign In captures token but never exchanges with Supabase. Backend accepts any token in debug.
**Files:** `AuthService.swift`, `backend/app/routes/deps.py`
**Fix:** Add Supabase `signInWithIdToken(provider: .apple)` after Apple credential received. Store and refresh Supabase JWT.
**Effort:** 1 day
**Why it matters:** No auth = no user accounts = no subscription billing = no revenue.

### 4. 🟢 StrokeDetector `midX` Operator Precedence Bug
**Impact:** Forehand vs backhand misclassified when one shoulder isn't detected.
**File:** `StrokeDetector.swift`
**Fix:** Wrap each `??` expression in parentheses.
**Effort:** 15 minutes

### 5. 🟢 OverlayRenderer `uiColor(any ShapeStyle)` Returns White
**Impact:** All skeleton/overlay colors render as white regardless of theme.
**File:** `OverlayRenderer.swift`
**Fix:** Implement proper ShapeStyle → UIColor conversion or refactor call sites to pass `Color` directly.
**Effort:** 30 minutes

### 6. 🟣 PoseEstimationService Blocks Async Threads
**Impact:** Synchronous Vision calls on cooperative thread pool. Will hang on long videos (30+ seconds).
**File:** `PoseEstimationService.swift`
**Fix:** Dispatch Vision work to the declared `processingQueue` using `withCheckedThrowingContinuation`.
**Effort:** 1 hour

### 7. 🟣 Missing Privacy Manifest (PrivacyInfo.xcprivacy)
**Impact:** Apple will reject the app without it (required since Spring 2024).
**Fix:** Create `PrivacyInfo.xcprivacy` with required privacy nutrition labels.
**Effort:** 30 minutes

### 8. 🟣 Backend Debug Mode Accepts Any Auth Token
**Impact:** If `debug=True` leaks to production, all requests auth as same user.
**File:** `backend/app/config.py`
**Fix:** Ensure production deployment sets `DEBUG=false`. Add safeguard.
**Effort:** 15 minutes

---

## TIER 1: HIGH PRIORITY — Must Fix Before App Store

### 9. 🟢 Upgrade Backend Model: GPT-4o → GPT-5.4
**File:** `backend/app/config.py`
**Fix:** Change `openai_model` default. Also add env var support for model switching.
**Effort:** 15 minutes (config), 2-4 hours (prompt optimization for 5.4)
**Prompt changes for GPT-5.4:**
- Remove verbose JSON template — 5.4 handles schema adherence better
- Use `response_format: { type: "json_schema" }` for guaranteed structure
- Switch image detail from `"low"` to `"high"` — 5.4 vision is dramatically better
- Increase `max_tokens` to 12000 for richer coaching narratives

### 10. 🟢 Connect VoiceFeedbackService to Live Recording
**Impact:** "Nice hip rotation!" spoken aloud during recording would be a massive differentiator.
**Files:** `RecordView.swift`, `VoiceFeedbackService.swift`
**Dependency:** Requires #2 (LiveSwingAnalyzer connected first)
**🟣 Opus warning:** AVSpeechSynthesizer conflicts with AVAudioSession during recording — needs audio session management.
**Effort:** 1 day (including audio session fix)

### 11. 🟢 Upgrade to VNDetectHumanBodyPose3DRequest (iOS 17+)
**Impact:** 3D pose gives depth info — dramatically better angle measurement, better forehand/backhand detection.
**File:** `PoseEstimationService.swift`
**Effort:** 1 day

### 12. 🔵 No Offline Error Handling
**Impact:** Analysis fails with generic error when backend unreachable.
**Fix:** Detect offline state, queue analysis for later.
**Effort:** 4 hours

### 13. 🔵 No Volley Detection
**Impact:** `inferStrokeType` only returns forehand/backhand/serve. Volleys listed as a feature but never classified.
**Fix:** Add wrist position + velocity profile for volley detection.
**Effort:** 4 hours

### 14. 🟣 Start Pose Extraction Immediately After Recording
**Impact:** Currently waits for user to tap into session before processing starts.
**Fix:** Trigger extraction in background right after recording stops.
**Effort:** 4 hours

### 15. 🟣 Show Skeleton Playback During "AI Analyzing" Wait
**Impact:** Keeps users engaged during 30-60 second GPT wait.
**Fix:** Display extracted poses playing back with overlay while waiting for API response.
**Effort:** 4 hours

### 16. 🟣 Bundle a Demo Analysis for Onboarding
**Impact:** Users see the full "wow" experience before they even record.
**Fix:** Ship a pre-computed sample session with results.
**Effort:** 1 day

### 17. 🟣 SwiftData `#Predicate` May Crash at Runtime
**Impact:** `status.rawValue == "ready"` in `ProgressDashboardView` — SwiftData has limited predicate expression support.
**Fix:** Test on device, potentially restructure query.
**Effort:** 1 hour

### 18. 🟣 Memory: 20 Full-Res UIImages in Memory (~150MB+)
**Impact:** Could trigger memory warnings or crashes on older devices.
**Fix:** Stream key frames to disk, load on demand.
**Effort:** 4 hours

### 19. 🟣 CameraService `stopRunning()` Blocks Main Thread
**Fix:** Dispatch to background queue.
**Effort:** 30 minutes

---

## TIER 2: POLISH — v1.1

| # | Issue | Source | Effort |
|---|-------|--------|--------|
| 20 | Add rate limiting to /analyze endpoint | 🟣 | 2 hours |
| 21 | Restrict CORS origins | 🟢 | 15 min |
| 22 | Add retry logic to AnalysisAPIService | 🟣 | 3 hours |
| 23 | Server-side StoreKit receipt validation | 🟣 | 2 days |
| 24 | SwiftData migration strategy | 🟣 | 1 day |
| 25 | Replace logger analytics with Mixpanel/PostHog | 🟣 | 1 day |
| 26 | Fix theme color propagation for runtime switching | 🟣 | 4 hours |
| 27 | Feedback retry queue on app launch | 🟣 | 2 hours |
| 28 | Replace `python-jose` with `PyJWT` | 🟣 | 2 hours |
| 29 | Supabase `freeAnalysesUsed` sync (not just UserDefaults) | 🔵 | 4 hours |
| 30 | Share card with actual video frame composite | 🔵 | 4 hours |
| 31 | Compress pose JSON (gzip) before upload | 🔵 | 2 hours |

---

## TIER 3: PHASE 2 FEATURES (from Josh's vision, March 10)

| # | Feature | Effort | Pricing Tier |
|---|---------|--------|-------------|
| 32 | **Drills Library** — curated video content | 2 weeks | Core ($29) |
| 33 | **Side-by-Side Pro Compare** — your swing vs pro | 1 week (manual clips) | Pro ($59) |
| 34 | **Community** — social layer (start with Discord) | 1 week | Pro ($59) |
| 35 | **Coach Mode** — film TV during match, get AI breakdown | 2 weeks | Pro ($59) |
| 36 | **Pro Swing Scraper** — AI clips tournament feeds | 4 weeks | Elite ($129) |
| 37 | **Real-time AR Overlay** via ARKit | 2 weeks | Future |
| 38 | **Android** (React Native or native Kotlin) | 8 weeks | Future |
| 39 | **Apple Watch companion** | 1 week | Future |
| 40 | **Offline analysis** (on-device LLM) | 2 weeks | Future |

---

## RECOMMENDED BUILD SEQUENCE

### Sprint 1: "Make It Real" (Days 1-3)
**Goal:** Fix the lies. Make everything that exists actually work.

| Day | Tasks | Result |
|-----|-------|--------|
| **Day 1 AM** | Fix #1 (backend images), #4 (midX bug), #5 (white overlay), #8 (debug mode) | GPT actually sees video frames |
| **Day 1 PM** | Fix #6 (async Vision), #7 (privacy manifest), #19 (stopRunning), #9 (upgrade to GPT-5.4) | Stable pipeline, better model |
| **Day 2** | Fix #2 (connect LiveSwingAnalyzer) — add AVCaptureVideoDataOutput, wire real-time Vision pipeline | REAL live skeleton during recording |
| **Day 3 AM** | Fix #10 (voice feedback + audio session) | "Nice hip rotation!" spoken during recording |
| **Day 3 PM** | Fix #3 (auth flow — Supabase exchange) | Real user accounts work |

**Sprint 1 outcome:** The app does what it claims. Live skeleton, voice coaching, GPT sees images, auth works. This is your TestFlight build.

### Sprint 2: "Make It Wow" (Days 4-7)
**Goal:** First-session experience that makes people text their friends.

| Day | Tasks | Result |
|-----|-------|--------|
| **Day 4** | Fix #14 (auto-start extraction), #15 (skeleton during wait), #11 (3D pose upgrade) | Faster, richer analysis |
| **Day 5** | Fix #16 (bundle demo session), #13 (volley detection), #17 (predicate crash) | Onboarding wow, complete stroke types |
| **Day 6** | Fix #12 (offline handling), #18 (memory optimization), prompt tuning for GPT-5.4 | Stable on all devices |
| **Day 7** | Full end-to-end testing, TestFlight internal build | Ship to beta testers |

**Sprint 2 outcome:** App Store-quality experience. Demo-worthy for investors.

### Sprint 3: "Make It Premium" (Weeks 2-3)
**Goal:** Pro features that justify $59/mo pricing.

- Side-by-side pro compare (manually curated clips)
- Drills library v1 (20 curated drill videos)
- Share cards with actual frame composites
- StoreKit receipt validation
- Analytics integration

### Sprint 4: "Make It Sticky" (Weeks 3-4)
**Goal:** Retention + community.

- Community Discord launch
- Coach Mode v1 (film TV)
- Progress sharing
- Push notifications for practice reminders

---

## QUESTIONS FOR JOSH (Blocking Build)

These are the same 10 from earlier — need answers to start Sprint 1:

1. **Brand name:** "TennisIQ" or "Tennique"? Affects bundle ID, domain, everything.
2. **Supabase:** Is `ksfntpplbgtingcdizey` active? Schema deployed?
3. **OpenAI API key:** Configured in backend `.env`?
4. **Apple Developer:** App registered in App Store Connect? Certificates ready?
5. **Sample video:** Do you have tennis footage to test with?
6. **Backend hosting:** Railway? Vercel? Where does the API run?
7. **Domain:** Do you own tennisiq.com or tennique.com?
8. **Your iPhone model:** Need for camera capability testing.
9. **Pricing for v1 launch:** Start with single tier or full $29/$59/$129?
10. **React Native:** Ship native first? (Strong rec: yes)

---

*Saved at `tennique/TRIAGE-UNIFIED.md`*
