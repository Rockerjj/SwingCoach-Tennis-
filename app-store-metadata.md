# App Store Connect Metadata -- Tennis Coach AI

Copy this into App Store Connect when creating the app listing.

---

## App Information

- **Bundle ID**: `com.tenniscoachai.app`
- **SKU**: `tenniscoachai`
- **Primary Language**: English (US)
- **Primary Category**: Health & Fitness
- **Secondary Category**: Sports
- **Content Rights**: Does not contain third-party content
- **Age Rating**: 4+

---

## Version 1.0.0 Metadata

### Title (30 chars max)
```
Tennis Coach AI - Improve Fast
```

### Subtitle (30 chars max)
```
AI Stroke Analysis & Coaching
```

### Keywords (100 chars max, comma-separated, no spaces after commas)
```
tennis,coach,ai,stroke,analysis,serve,forehand,backhand,training,lessons,practice,technique,improve
```

### Promotional Text (170 chars max -- can be updated without app review)
```
Film your strokes. Get instant AI coaching. See your skeleton overlay, grades, and personalized drills for every forehand, backhand, and serve. 3 free analyses to start.
```

### Description (4000 chars max)
```
Stop guessing if your form is right. Tennis Coach AI uses advanced computer vision and GPT-4o to analyze every stroke you hit -- frame by frame -- and gives you the same level of feedback a private coach would.

HOW IT WORKS
1. Set up your phone courtside and hit Record
2. Play your game naturally -- forehands, backhands, serves, volleys
3. Get instant AI analysis with a full-body skeleton overlay on your video
4. See letter grades (A through F) for each stroke with detailed coaching breakdowns

WHAT YOU GET
- Real-time skeleton overlay showing your body mechanics during every stroke
- Individual grades for backswing, contact point, follow-through, stance, and toss
- Coaching cues that explain exactly what to fix and how
- Practice drills tailored to your specific weaknesses
- Progress tracking that shows your improvement over time
- Tactical gameplay notes to sharpen your match strategy

WHO IT'S FOR
- Recreational players who want to improve without expensive private lessons
- Competitive players looking for objective feedback on their technique
- Tennis coaches who want to supplement their teaching with AI analysis
- Anyone who has ever wondered "is my form actually good?"

PRICING
- 3 free analyses to see the magic
- Monthly or Annual subscription for unlimited analysis

Built with Apple Vision pose estimation (on-device, private) and GPT-4o coaching intelligence. Your videos never leave your device unless you choose to share them.

Questions? Reach us at support@tenniscoachai.com
```

### What's New (for v1.0.0)
```
Welcome to Tennis Coach AI! This is our first release featuring:
- AI-powered stroke analysis with skeleton overlay
- Coaching feedback with letter grades for every stroke
- Mechanics breakdown (backswing, contact point, follow-through, stance, toss)
- Progress tracking dashboard
- Three beautiful design themes
- Sign in with Apple & guest mode
```

---

## Screenshots Required

Upload for these device sizes:
- 6.7" (iPhone 15 Pro Max / 16 Pro Max) -- REQUIRED
- 6.5" (iPhone 14 Plus / 15 Plus)
- 5.5" (iPhone 8 Plus) -- if supporting older devices

### Screenshot Sequence (5 screens)

1. **Hero Shot**: Recording screen with camera preview active
   - Caption: "Film Your Game. Get AI Coaching."

2. **Skeleton Overlay**: Video playback showing pose skeleton on player
   - Caption: "See What Your Coach Sees"

3. **Coaching Cards**: Expanded coaching card showing grade + mechanics breakdown
   - Caption: "Every Stroke, Graded & Explained"

4. **Progress Dashboard**: Progress view with circular gauges and improvement chart
   - Caption: "Track Your Improvement Over Time"

5. **Session Overview**: Session summary with overall grade and stroke timeline
   - Caption: "Your Personal AI Tennis Coach"

---

## App Preview Video (optional but recommended)

- 15-30 seconds showing: Record -> Analyze -> See skeleton -> Read coaching
- Dimensions: 1290 x 2796 (6.7") or 1284 x 2778 (6.1")
- Format: H.264, AAC audio, .mp4 or .mov

---

## StoreKit Product Configuration

Create these in App Store Connect > Subscriptions:

### Subscription Group: "TennisCoachAI Premium"

| Product | Product ID | Price | Period | Level |
|---------|-----------|-------|--------|-------|
| Monthly Premium | `tenniscoachai_monthly` | $6.99 | 1 Month | 1 |
| Annual Premium | `tenniscoachai_annual` | $49.99 | 1 Year | 1 |

- Family Sharing: No
- Free Trial: Consider adding 7-day free trial to annual plan
- Subscription Group Display Name: "TennisCoachAI Premium"

---

## Review Information

### Contact Info
- First Name: [Your first name]
- Last Name: [Your last name]
- Phone: [Your phone]
- Email: support@tenniscoachai.com

### Demo Account
- Not required (app supports guest mode)

### Notes for Reviewer
```
This app uses the device camera to record tennis sessions. It then uses Apple Vision framework for on-device pose estimation and sends extracted pose data (not video) to our API for AI coaching analysis. The app requires a physical tennis court environment to demonstrate full functionality, but you can test the UI flow, onboarding, and subscription screens without recording. Guest mode is available -- no sign-in required to explore the app.
```
