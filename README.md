# TennisIQ

AI-powered tennis coaching through your iPhone camera. Record your sessions, get professional-level stroke analysis with visual overlays, and track your improvement over time.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   iPhone (On-Device)                 │
│                                                     │
│  Camera → Apple Vision (Pose) → Overlay Renderer    │
│             ↓                         ↑             │
│        Pose JSON + Key Frames    Feedback JSON      │
└──────────────┬──────────────────────┬───────────────┘
               ↓                      ↑
┌──────────────┴──────────────────────┴───────────────┐
│                  Cloud Backend                       │
│                                                     │
│  FastAPI → GPT-4o Vision → Structured Coaching JSON  │
│     ↕                                               │
│  Supabase (Postgres + Auth + Storage)               │
└─────────────────────────────────────────────────────┘
```

## Tech Stack

**iOS App**
- Swift 6 / SwiftUI
- AVFoundation (camera recording)
- Vision framework (on-device pose estimation)
- SwiftData (local persistence)
- StoreKit 2 (subscriptions)

**Backend**
- Python FastAPI
- OpenAI GPT-4o Vision API
- Supabase (Postgres, Auth, Storage)
- Deployed on Railway

## Project Structure

```
TennisIQ/
├── App/                    # App entry point, root navigation
├── Models/                 # SwiftData models + API types
├── Views/
│   ├── Record/             # Camera recording screen
│   ├── Sessions/           # Session list + Analysis Results (hero screen)
│   ├── Progress/           # Progress dashboard with charts
│   ├── Profile/            # Settings, subscription, theme picker
│   ├── Onboarding/         # 3-screen intro flow
│   └── Components/         # Shared UI components
├── ViewModels/             # MVVM view models
├── Services/
│   ├── CameraService       # AVFoundation camera management
│   ├── PoseEstimationService # Apple Vision pose extraction
│   ├── AnalysisAPIService  # Cloud API communication
│   ├── OverlayRenderer     # Skeleton + annotation drawing
│   ├── AuthService         # Sign in with Apple
│   └── SubscriptionService # StoreKit 2 purchases
├── Design/                 # 3 theme variants + design system
├── Utilities/              # Extensions, constants
└── Resources/              # Entitlements, assets

backend/
├── main.py                 # FastAPI app entry point
├── app/
│   ├── config.py           # Environment settings
│   ├── models.py           # Pydantic request/response models
│   ├── routes/             # API endpoints
│   ├── services/           # LLM coaching + progress calculator
│   └── prompts/            # Tennis coaching system prompts
├── supabase_schema.sql     # Database schema
├── requirements.txt
└── Dockerfile
```

## Setup

### Prerequisites
- Xcode 15+
- Python 3.12+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Supabase account
- OpenAI API key
- Apple Developer account (for Sign in with Apple + StoreKit)

### iOS App
```bash
# Generate Xcode project
cd "Tennis IQ"
xcodegen generate

# Open in Xcode
open TennisIQ.xcodeproj

# Update constants in TennisIQ/Utilities/Constants.swift:
# - Supabase URL + anon key
# - RevenueCat API key
```

### Backend
```bash
cd backend
cp .env.example .env
# Fill in your API keys in .env

pip install -r requirements.txt
uvicorn main:app --reload
```

### Database
1. Create a Supabase project
2. Run `supabase_schema.sql` in the SQL Editor
3. Enable Apple Sign In provider in Authentication settings

## Design Themes

Three visual schemes are included for prototyping:

| Theme | Aesthetic | Base | Accent |
|-------|-----------|------|--------|
| Court Vision | Dark Athletic Precision | `#0A0A0F` | `#C8FF00` (lime) |
| Grand Slam | Light Luxury Editorial | `#FAF8F5` | `#1B4332` (green) |
| Rally | Bold Sport-Tech | `#0C1222` | `#FF5C5C` (coral) |

Switch themes in Profile > Design Theme.

## MVP Scope

**Included:**
- Single camera recording (tripod/fence setup)
- Core 4 strokes: Forehand, Backhand, Serve, Volley
- AI stroke mechanics analysis with visual overlays
- Tactical gameplay feedback
- Progress tracking over time
- Subscription billing

**Future:**
- Real-time AR feedback during recording
- Multi-camera angle support
- Android app
- Social features
- Coach marketplace
