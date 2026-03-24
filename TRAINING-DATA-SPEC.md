# Tennique Training Data Pipeline — Implementation Spec

## In-App Consent Flow

### Settings Screen — New Toggle
```
┌─────────────────────────────────────────┐
│ 🧠 Improve Tennique                     │
│                                         │
│ Help make Tennique's coaching smarter   │
│ by contributing your swing videos to    │
│ train our AI. Your data is anonymous    │
│ and you can opt out anytime.            │
│                                         │
│ [Toggle: OFF by default]                │
│                                         │
│ Learn more → (links to privacy policy)  │
└─────────────────────────────────────────┘
```

### First Toggle-On — Confirmation Dialog
```
┌─────────────────────────────────────────┐
│ Help Improve Tennique?                  │
│                                         │
│ Your swing videos (with pose overlay)   │
│ will be securely uploaded to help       │
│ train our AI coaching models.           │
│                                         │
│ • Videos are de-identified (anonymous)  │
│ • You can opt out anytime in Settings   │
│ • Doesn't affect your app features     │
│                                         │
│ [Cancel]              [I'm In]          │
└─────────────────────────────────────────┘
```

## Backend Pipeline

### 1. Video Upload (when user opts in)
- After each swing analysis completes AND user is opted in:
  - Upload the pose-overlay video (NOT raw camera footage) to training bucket
  - Include metadata: stroke_type, analysis_results, device_model, video_duration
  - Use anonymous_user_id (NOT Apple ID or account email)
  - Store in Supabase Storage bucket: `training-data/`

### 2. Supabase Schema Addition
```sql
-- Training data contributions
CREATE TABLE training_contributions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  anonymous_user_id TEXT NOT NULL,
  video_storage_path TEXT NOT NULL,
  stroke_type TEXT,
  analysis_json JSONB,
  pose_data JSONB,
  device_model TEXT,
  video_duration_seconds FLOAT,
  contributed_at TIMESTAMPTZ DEFAULT NOW(),
  used_in_training BOOLEAN DEFAULT FALSE,
  deletion_requested_at TIMESTAMPTZ
);

-- User opt-in tracking
ALTER TABLE profiles ADD COLUMN training_opt_in BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN training_opt_in_date TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN anonymous_training_id TEXT DEFAULT gen_random_uuid()::TEXT;
```

### 3. Opt-Out Flow
- User toggles off in Settings
- Set `training_opt_in = false` on profile
- Mark all their contributions: `deletion_requested_at = NOW()`
- Cron job (daily): delete videos where `deletion_requested_at` is >0 and <30 days old
- After deletion: remove row from `training_contributions`

### 4. Data Export for Training
- Script to export all opted-in, non-deleted videos + metadata
- Format: video files + JSONL metadata file
- Filter: only videos with confirmed stroke_type and quality analysis
- Target: 5,000 clips minimum before first training run

## iOS Implementation Notes

### SwiftUI Toggle
- Add `@AppStorage("trainingOptIn")` boolean
- On toggle-on: show confirmation alert, call API to update profile
- On toggle-off: call API to update profile + trigger deletion

### Upload Logic
- Add to `SwingAnalysisViewModel` post-analysis flow
- Only upload if `trainingOptIn == true`
- Upload in background (URLSession background task)
- Don't block UI — upload happens after analysis is shown to user
- Retry logic: 3 attempts, exponential backoff
- Skip upload if on cellular (configurable, default: WiFi only)

## Privacy Safeguards
- ✅ Pose overlay video only (not raw camera footage)
- ✅ Anonymous user ID (not linked to Apple ID)
- ✅ Opt-in only (OFF by default)
- ✅ Can opt out anytime with 30-day deletion
- ✅ WiFi-only upload by default
- ✅ No face data extracted or stored
- ✅ Compliant with App Store guidelines (user consent + clear disclosure)
