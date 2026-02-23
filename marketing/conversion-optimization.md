# Conversion Optimization Playbook

## Priority Order

Optimize these screens in this exact order. Each builds on the last.

---

## 1. Paywall Screen (Highest Leverage)

This is the single most important screen for revenue. Every 1% improvement here directly increases MRR.

### Current State
- Shows after 3 free analyses
- Displays monthly ($6.99) and annual ($49.99) options
- Basic feature comparison

### Optimization Tests

**Test 1: Value Framing**
- Control: "Unlimited analyses"
- Variant A: "Unlimited analyses, progress tracking, and drills — less than a single tennis lesson"
- Variant B: Show a "what you'll miss" preview — blur or lock a coaching card

**Test 2: Social Proof**
- Add user count: "Join 500+ tennis players improving with AI"
- Add testimonial quote from a real user
- Show average improvement stat: "Users improve 1.5 grades in 30 days"

**Test 3: Pricing Presentation**
- Test showing daily cost: "$0.23/day for unlimited coaching"
- Test showing comparison: "Less than 1% the cost of a private lesson"
- Test anchoring: Show the annual plan first (it's the better deal)
- Test weekly option: $2.99/week (lower commitment, higher LTV test)

**Test 4: Urgency/Scarcity**
- "First 100 subscribers get 40% off" (launch only)
- "Limited introductory pricing"
- Free trial: "Try 7 days free, then $6.99/month"

### Implementation Notes
- Track `subscription_viewed` -> `subscription_purchased` conversion rate
- Run each test for at least 100 paywall views before deciding
- Keep a decision log: what you tested, results, what you shipped

---

## 2. Free-to-Paid Trigger

### Current: 3 Free Analyses

This is a critical number. Too few = users don't get enough value to convert. Too many = they never need to pay.

**Test Options:**
| Free Analyses | Hypothesis |
|--------------|------------|
| 2 | Users decide faster but may not see enough value |
| 3 (current) | Baseline |
| 5 | More value shown = higher conversion for those who do convert |
| Unlimited (gated features) | Free analysis with locked coaching details |

**Feature Gating Alternative:**
Instead of limiting analysis count, give unlimited free analyses but gate premium features:
- Free: See overall grade only
- Premium: Full coaching breakdown, mechanics details, practice drills, progress tracking

This lets users keep using the app (retention) while still incentivizing upgrade (depth).

**Test Approach:**
1. Start with current (3 free analyses)
2. After 2 weeks of data, test feature gating if conversion < 5%
3. Track: free_to_paid_rate, time_to_convert, churn_rate

---

## 3. Onboarding Flow

### Goal: Show the "Aha Moment" Before Effort

Most users won't record a session if they don't understand what they'll get. Show them a sample analysis during onboarding.

**Current Flow:**
Screen 1 -> Screen 2 -> Screen 3 -> Main App

**Optimized Flow:**
1. Welcome screen with value prop
2. **Sample Analysis Demo**: Show a pre-recorded analysis with skeleton overlay, grades, and coaching. Let users scroll through a sample coaching card. This is the "aha moment."
3. Permission screen (camera, optional notifications)
4. Skill level selection (beginner, intermediate, advanced)
5. Main App — guided to Record tab with a "Record Your First Session" prompt

**Key Changes:**
- Show value before asking for permissions
- Let users interact with a sample result
- Personalize by asking skill level upfront
- Clear next step after onboarding completes

---

## 4. First Analysis Experience

### This Makes or Breaks Retention

If the first analysis is slow, confusing, or underwhelming, users churn.

**Speed:**
- Target: Under 30 seconds from "analyze" tap to results
- Show progress with clear phases: "Extracting poses..." -> "AI analyzing..."
- Add fun loading copy: "Your AI coach is studying your backswing..."

**Quality:**
- Ensure the skeleton overlay renders correctly on first try
- Auto-play the video at 0.25x during key strokes
- Default to the most interesting stroke (highest grade variance)

**Post-Analysis Hooks:**
- Prompt to share: "Share your analysis on Instagram" button
- Prompt to record again: "Record another session to compare"
- Show what's locked: "Subscribe to see your progress over time"

---

## 5. Post-Analysis Share Prompt

After showing analysis results, prompt sharing. This is the growth loop.

**Prompt Design:**
```
[Analysis results visible above]

┌─────────────────────────────┐
│  🎾 Share Your Analysis    │
│                             │
│  Post your AI-graded stroke │
│  and challenge your tennis  │
│  friends.                   │
│                             │
│  [Share to Instagram]       │
│  [Share to TikTok]          │
│  [Save to Camera Roll]      │
│                             │
│  Maybe later                │
└─────────────────────────────┘
```

---

## 2-Week Iteration Cycle

### Week A: Measure & Decide
- **Monday**: Pull funnel metrics for past week
- **Tuesday**: Identify biggest drop-off point
- **Wednesday**: Design fix (sketch, write copy, plan implementation)
- **Thursday**: Get feedback from 2-3 users on the proposed fix
- **Friday**: Finalize implementation plan

### Week B: Build & Measure
- **Monday-Wednesday**: Implement the fix
- **Thursday**: TestFlight build, internal testing
- **Friday**: Ship to App Store
- **Weekend**: Monitor early data

### Repeat

**Prioritization Rule:** Always pick the change that impacts the metric "free user -> paying subscriber" the most. If paywall conversion is 2%, fixing the paywall is 10x more impactful than improving the onboarding — even if onboarding also needs work.

---

## Metrics Dashboard Template

Update weekly:

| Week | Installs | Onboarding % | Recording % | Analysis % | Paywall View % | Convert % | MRR |
|------|----------|-------------|-------------|------------|---------------|-----------|-----|
| W1   |          |             |             |            |               |           |     |
| W2   |          |             |             |            |               |           |     |
| W3   |          |             |             |            |               |           |     |
| W4   |          |             |             |            |               |           |     |
