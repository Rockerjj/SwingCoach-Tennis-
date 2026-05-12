# App Store Connect Submission Checklist — Tennique v1.0.0

One-pager. Mechanical fill-in. Every field below maps to its source-of-truth value in `app-store-metadata.md`. Walk through top to bottom — do not improvise copy in App Store Connect.

**Prereqs (hard gates):**
- [ ] Apple Developer Program enrollment active (`developer.apple.com/enroll`, $99/yr) ← currently blocking
- [ ] D-U-N-S number assigned (if enrolling as organization; not needed for Individual)
- [ ] Xcode signed in to the Apple ID that owns the Developer account
- [ ] Bundle ID `com.tennique.app` registered under Certificates, Identifiers & Profiles → Identifiers (do this before creating the ASC record)

---

## Step 1 — Create the App Record
**Where:** App Store Connect → My Apps → **+** → New App

| Field | Value |
|---|---|
| Platforms | **iOS** |
| Name | `Tennique - Improve Fast` |
| Primary Language | `English (U.S.)` |
| Bundle ID | `com.tennique.app` (must already be registered) |
| SKU | `tennique` |
| User Access | Full Access |

Click **Create**. The app shell exists.

---

## Step 2 — App Information (left sidebar → App Information)

| Field | Value |
|---|---|
| Subtitle | `AI Stroke Analysis & Coaching` |
| Primary Category | **Health & Fitness** |
| Secondary Category | **Sports** |
| Content Rights | "Does not contain, show, or access third-party content" → **No** (uncheck) |
| Age Rating | **4+** (questionnaire → answer "None" to all violent/sexual/etc. categories) |

**Privacy Policy URL:** `https://tennique.com/privacy` (must be live before submission — if not ready, host a placeholder on Vercel landing page)

---

## Step 3 — Pricing and Availability

| Field | Value |
|---|---|
| Price Schedule | **Free** (paywall handled via in-app subscriptions) |
| Availability | **All countries/regions** (default) |
| App Distribution Methods | **Public on the App Store** |

---

## Step 4 — Version 1.0.0 → iOS App (left sidebar → 1.0.0 Prepare for Submission)

### 4a. Promotional Text (170 chars max — editable post-launch without review)
```
Film your strokes. Get instant AI coaching. See your skeleton overlay, grades, and personalized drills for every forehand, backhand, and serve. 3 free analyses to start.
```

### 4b. Description (4000 chars max)
Paste the full block from `app-store-metadata.md` § Description. **Do not edit in the ASC textarea** — paste only.

### 4c. Keywords (100 chars max, comma-separated, no spaces after commas)
```
tennis,coach,ai,stroke,analysis,serve,forehand,backhand,training,lessons,practice,technique,improve
```

### 4d. Support URL
`https://tennique.com/support` *(or `https://tennique.com` if support page isn't live yet — must resolve)*

### 4e. Marketing URL (optional)
`https://tennique.com` *(if landing page is live)*

### 4f. What's New in This Version
*(field only appears after first build is uploaded — paste from § "What's New" in metadata file)*

---

## Step 5 — App Privacy
**Where:** App Information → App Privacy → Get Started

Answer the questionnaire. Mark these data types as collected:

| Data Type | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|
| Email Address (Sign in with Apple) | Yes | No | App Functionality, Account Management |
| User ID | Yes | No | App Functionality |
| Video data (pose estimation only — not stored) | **No** (processed on-device + ephemeral) | No | App Functionality |
| Purchase History | Yes | No | App Functionality |
| Performance Data (crashes) | No | No | Analytics |

**Important:** answer truthfully. If videos *never* leave device, mark "Data Not Collected" for video. The reviewer note in metadata says "extracted pose data (not video) to our API" — confirm this matches the actual code before clicking submit.

---

## Step 6 — Screenshots
**Required:** 6.7" iPhone (1290 × 2796) — minimum 3, maximum 10.
**Recommended:** 6.5" iPhone (1242 × 2688) — optional but reduces ASC complaints.

Use the 5-screen sequence from `app-store-metadata.md`:

1. Recording screen with camera preview — **"Film Your Game. Get AI Coaching."**
2. Skeleton overlay on playback — **"See What Your Coach Sees"**
3. Coaching card with grade + mechanics breakdown — **"Every Stroke, Graded & Explained"**
4. Progress dashboard with gauges — **"Track Your Improvement Over Time"**
5. Session overview with stroke timeline — **"Your Personal AI Tennis Coach"**

**Production tip:** Take screenshots in iOS Simulator (iPhone 16 Pro Max) for clean pixel sizes. Caption text overlay can be added in Figma/Sketch before upload.

---

## Step 7 — App Preview Video (optional but recommended)

- Length: 15–30 seconds
- Dimensions: 1290 × 2796 (6.7") or 1284 × 2778 (6.1")
- Format: H.264, AAC, .mp4 or .mov
- Content arc: **Record → Analyze → See Skeleton → Read Coaching**

Skip for v1.0.0 if it slows the launch. Add post-launch.

---

## Step 8 — In-App Purchases / Subscriptions
**Where:** Sidebar → Monetization → Subscriptions → Create Subscription Group

### Group: `Tennique Premium`

| Field | Value |
|---|---|
| Reference Name | `Tennique Premium` |
| Subscription Group Display Name | `Tennique Premium` |

### Subscription 1: Monthly

| Field | Value |
|---|---|
| Reference Name | `Monthly Premium` |
| Product ID | `tennique_monthly` |
| Duration | **1 Month** |
| Level | 1 |
| Price | **$6.99 USD** |
| Family Sharing | **Off** |
| Free Trial | None (or 7-day if matching Annual) |
| Localization (en-US) Display Name | `Tennique Premium Monthly` |
| Localization Description | `Unlimited AI stroke analysis, coaching feedback, and progress tracking.` |

### Subscription 2: Annual

| Field | Value |
|---|---|
| Reference Name | `Annual Premium` |
| Product ID | `tennique_annual` |
| Duration | **1 Year** |
| Level | 1 |
| Price | **$49.99 USD** |
| Family Sharing | **Off** |
| Free Trial | **7 days** (recommended) |
| Localization (en-US) Display Name | `Tennique Premium Annual` |
| Localization Description | `Unlimited AI stroke analysis, coaching feedback, and progress tracking. Save 40% vs. monthly.` |

**Review screenshot required per IAP:** A screenshot of the paywall showing each product. Take in simulator after StoreKit Configuration is wired.

---

## Step 9 — Build Upload (Xcode side)

1. In Xcode: open `Tennique.xcodeproj` *(rename pending — currently `TennisIQ.xcodeproj` in `project.yml`)*
2. Select **Any iOS Device (arm64)** as build target
3. Product → Archive
4. Organizer → Distribute App → App Store Connect → Upload
5. Wait for build to process in ASC (5–30 min)
6. Build appears under **TestFlight** tab → **iOS Builds** with "Processing" → resolved to a version number

**Export Compliance:** When the build is uploaded, ASC will prompt:
- Does your app use encryption? → **Yes** (HTTPS counts)
- Does it qualify for exemption? → **Yes** (standard HTTPS exemption)

---

## Step 10 — TestFlight (internal first)
1. TestFlight → Internal Testing → Create a Group ("Internal QA")
2. Add yourself + Katie as internal testers (uses Apple IDs)
3. Add build → testers get invite email
4. Install TestFlight app on iPhone 15 Pro Max → install Tennique
5. Run through the full flow on a real court before opening external TestFlight

---

## Step 11 — Submit for Review (when ready)
**Where:** 1.0.0 Prepare for Submission → Add Build → Select the TestFlight-validated build → fill remaining required fields → **Submit for Review**

### Review Information (last block before submit)

| Field | Value |
|---|---|
| Sign-in Required | **No** (Guest mode + Sign in with Apple) |
| Contact Info First Name | Josh |
| Contact Info Last Name | Rockers |
| Phone | *(fill in from contacts)* |
| Email | `support@tennique.com` *(or personal email if domain mail not configured yet)* |
| Notes | Paste full text from `app-store-metadata.md` § "Notes for Reviewer" |

### Version Release
- **Manually release this version** (recommended for v1.0.0 — gives you a coordinated launch moment)

---

## Pre-Submit Final Check

- [ ] App icon present in Asset Catalog (1024×1024 marketing icon required)
- [ ] Launch screen storyboard or asset present
- [ ] Privacy Policy URL resolves (`https://tennique.com/privacy`)
- [ ] Support URL resolves
- [ ] All 3+ screenshots uploaded for 6.7"
- [ ] StoreKit products created and "Ready to Submit"
- [ ] Subscription paywall screenshot uploaded for each IAP
- [ ] Build selected (TestFlight-validated)
- [ ] Export Compliance answered
- [ ] App Privacy questionnaire complete
- [ ] Age rating questionnaire complete
- [ ] Reviewer notes pasted

---

## After Submit
- Review SLA: usually **24–48 hours** in 2026 (sometimes same day)
- If rejected: read the Resolution Center message, fix, resubmit (don't argue unless they're wrong about a fact)
- If approved + "Manually release": click **Release This Version** when you're ready
- App goes live worldwide ~30 min after release click

---

## Open Items Before Step 1 Is Possible
1. **Apple Developer Program enrollment** (status: open since 2026-03-17) — start tonight, 24–48h activation
2. **`tennique.com` DNS pointed at landing page** with `/privacy` and `/support` pages live (or placeholder pages that resolve)
3. **Rename `TennisIQ.xcodeproj` → `Tennique.xcodeproj`** in `project.yml` and regen (separate PR — code change, not in this docs sweep)
4. **App icon 1024×1024** finalized
5. **5 production-quality screenshots** generated from real device + Figma overlay

**Estimated time from "Developer enrollment activated" → "Submitted for Review":** 4–6 focused hours assuming screenshots + icon are ready.
