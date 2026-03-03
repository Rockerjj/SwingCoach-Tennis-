# Feedback Analysis & User Interview Framework

## Quantitative Funnel Tracking

### Key Metrics to Track Weekly

Track these using the AnalyticsService events. Export from your analytics dashboard weekly.

| Funnel Step | Event | Target Rate |
|-------------|-------|-------------|
| Install | app_opened (unique) | Baseline |
| Onboarding Complete | onboarding_completed / app_opened | 70%+ |
| First Recording | recording_started / onboarding_completed | 60%+ |
| First Analysis | analysis_completed / recording_started | 80%+ |
| Second Analysis | 2nd analysis_completed / 1st | 50%+ |
| Paywall View | subscription_viewed / analysis_completed (3rd) | 90%+ |
| Subscribe | subscription_purchased / subscription_viewed | 10-15%+ |

### Identifying Drop-off Points

Run this analysis weekly:
1. Pull event counts for each funnel step
2. Calculate conversion between each step
3. Identify the step with the largest absolute drop-off
4. That's your highest-priority fix for the week

**Example:**
- 500 installs -> 350 onboarding complete (70%) -- OK
- 350 onboarding -> 140 first recording (40%) -- PROBLEM
- 140 recording -> 112 analysis complete (80%) -- OK
- Fix: Users aren't recording. Investigate why (confusing UI? too many steps to camera? permission anxiety?)

### Supabase SQL for Feedback Dashboard

```sql
-- Create user_feedback table
CREATE TABLE IF NOT EXISTS user_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    comment TEXT DEFAULT '',
    app_version TEXT DEFAULT '',
    device_model TEXT DEFAULT '',
    ios_version TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_feedback ENABLE ROW LEVEL SECURITY;

-- Allow inserts from any authenticated or anonymous user
CREATE POLICY "Allow feedback inserts" ON user_feedback
    FOR INSERT TO anon, authenticated
    WITH CHECK (true);

-- Only allow service role to read all feedback
CREATE POLICY "Service role can read feedback" ON user_feedback
    FOR SELECT TO service_role
    USING (true);

-- Average rating over time
SELECT 
    DATE_TRUNC('week', created_at) AS week,
    AVG(rating)::NUMERIC(3,1) AS avg_rating,
    COUNT(*) AS total_feedback
FROM user_feedback
GROUP BY week
ORDER BY week DESC;

-- Common themes in comments (manual review helper)
SELECT rating, comment, created_at
FROM user_feedback
WHERE comment != ''
ORDER BY created_at DESC
LIMIT 50;
```

---

## Qualitative Feedback Collection

### In-App Feedback (already built)
- Shows after 2nd analysis
- Collects 1-5 star rating + optional comment
- Stored in Supabase `user_feedback` table

### App Store Review Monitoring
- Check App Store Connect daily for the first month
- Respond to EVERY review within 24 hours
- Categorize reviews:
  - **UX Issue**: Something confusing or broken
  - **Feature Request**: Something they want added
  - **Quality Concern**: AI analysis quality feedback
  - **Pricing Concern**: Too expensive / not worth it
  - **Positive**: Genuinely happy user

### Review Response Templates

**Positive Review (4-5 stars):**
```
Thank you so much for the kind review! It means a lot. If you ever 
want to suggest features or have feedback, reach out anytime at 
support@tennisiq.com. Keep improving your game! 🎾
```

**Negative Review (1-2 stars, UX issue):**
```
Thank you for the feedback — we're sorry about the [issue]. We're 
actively working on improving this. We just pushed a fix in [version]. 
Could you try updating the app? If the issue persists, please reach 
out to support@tennisiq.com so we can help directly.
```

**Negative Review (1-2 stars, analysis quality):**
```
We appreciate the honest feedback. Our AI analysis is constantly 
improving — we take quality seriously. If you'd be open to sharing 
the specific session that felt inaccurate, email us at 
support@tennisiq.com and we'll investigate. Your input directly 
shapes our improvements.
```

---

## User Interview Framework

### Who to Interview
- Users who completed 3+ analyses (engaged users)
- Users who hit the paywall but didn't subscribe (conversion insight)
- Users who subscribed (understand what convinced them)
- Users who churned (understand what disappointed them)

### How to Find Them
- Add "Chat with the Founder" link in Profile screen (already planned)
- Email users who submitted feedback with high ratings
- Reach out to users who reviewed on the App Store
- Post in your community/social channels: "I'm interviewing users"

### Interview Script (15-20 minutes)

```
Opening (2 min):
"Thanks for taking the time. I'm trying to make Tennis IQ 
better and your feedback is really valuable. No wrong answers."

Usage (3 min):
1. "How often do you play tennis?"
2. "How did you first hear about Tennis IQ?"
3. "How often do you use the app?"

Experience (5 min):
4. "Walk me through the last time you used the app. What did you do?"
5. "What was the most useful part of the analysis?"
6. "Was there anything confusing or frustrating?"
7. "How accurate did the AI coaching feel compared to advice 
   you've gotten from a human coach?"

Value (5 min):
8. "What would make you use the app more?"
9. "Is there a feature you wish existed?"
10. "Would you recommend this to a tennis friend? Why or why not?"

Pricing (3 min):
11. "What do you think about the pricing?"
12. "What would make the premium subscription a no-brainer for you?"

Closing (2 min):
"Is there anything else you want to share? Thank you so much."
```

### Interview Notes Template

| Question | User 1 | User 2 | User 3 | Pattern |
|----------|--------|--------|--------|---------|
| How found app | | | | |
| Most useful part | | | | |
| Most frustrating | | | | |
| Feature request | | | | |
| Would recommend? | | | | |
| Pricing opinion | | | | |

---

## Weekly Feedback Review Process

**Every Monday (30 minutes):**
1. Pull analytics funnel data from past week
2. Read all new App Store reviews (respond to each)
3. Read all new in-app feedback
4. Review user interview notes
5. Update the feedback themes tracker:

| Theme | Count | Severity | Status |
|-------|-------|----------|--------|
| Analysis takes too long | 5 | High | In progress |
| Want video export | 8 | Medium | Planned |
| Pricing too high | 3 | Low | Monitor |
| Skeleton overlay glitchy | 2 | High | Fix this week |

6. Pick the #1 issue to fix this week
7. Add it to the sprint
