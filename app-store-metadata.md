# App Store Connect Metadata — Tennique

Copy this into App Store Connect when creating the app listing.

---

## App Information

- **Bundle ID**: `com.tennique.app`
- **SKU**: `tennique-v1`
- **Primary Language**: English (US)
- **Primary Category**: Health & Fitness
- **Secondary Category**: Sports
- **Content Rights**: Does not contain third-party content
- **Age Rating**: 4+

---

## Version 1.0.0 Metadata

### Title (30 chars max)
```
Tennique - AI Tennis Coach
```

### Subtitle (30 chars max)
```
Film Swings. Fix Your Game.
```

### Keywords (100 chars max, comma-separated, no spaces after commas)
```
tennis,coach,ai,stroke,analysis,serve,forehand,backhand,training,lessons,practice,technique,improve
```

### Promotional Text (170 chars max — can be updated without app review)
```
Film your strokes. Get instant AI coaching with skeleton overlays, grades, and personalized drills for every swing. 3 free analyses to start. No coach required.
```

### Description (4000 chars max)
```
Stop guessing if your form is right.

Tennique uses Apple Vision body tracking and GPT-5.4 to analyze every stroke you hit — frame by frame — and gives you the kind of feedback that used to require a $120/hour private coach.

HOW IT WORKS
1. Prop your phone up courtside and hit Record
2. Play your game naturally — forehands, backhands, serves, volleys
3. Get instant AI analysis with a real-time skeleton overlay on your video
4. See coaching grades for each stroke with specific feedback on what to fix

WHAT YOUR COACH TELLS YOU
• "Get your racket back earlier — it should be ready before the ball bounces"
• "Your shoulder turn is too small — show your back to your opponent"
• "Great contact point — arm is extended, ball is well out in front"
• A specific drill for every issue, with reps and what to focus on
• Your best swing highlighted so you know what you're doing right

NOT WHAT YOU GET
• No confusing angle measurements or physics jargon
• No generic "looks good" feedback
• No guessing what to practice next

FEATURES
• Real-time skeleton overlay during recording with live coaching cues
• Voice feedback speaks coaching tips while you play ("Extend through the ball!")
• AI grades every phase: ready position, backswing, contact, follow-through, recovery
• Visual corrections showing your skeleton morphing to the ideal position
• One hero coaching cue per stroke type — the single most important thing to fix
• Your best swing highlighted alongside what needs work
• Practice drills with YouTube demo videos
• Progress tracking over time
• Share cards for social media

WHO IT'S FOR
• Recreational players who want to improve without expensive lessons
• Competitive players who want data between coaching sessions
• Coaches who want a tool to show students what to fix
• Anyone who's ever wondered "what am I doing wrong?"

PRICING
• 3 free analyses — no credit card required
• Tennique Pro: unlimited analyses, priority processing

REQUIREMENTS
• iPhone 12 or newer (iOS 17+)
• Works best with phone propped 10-15 feet away at waist height
• Front or back camera
```

### What's New (for version updates)
```
Welcome to Tennique! Your AI tennis coach is ready. Film your strokes and get instant coaching feedback with skeleton overlays, grades, and personalized drills.
```

---

## Review Notes (for Apple Review Team)
```
Tennique is an AI-powered tennis coaching app. Users record themselves playing tennis, and the app uses Apple's Vision framework for body pose detection and OpenAI's GPT-5.4 for coaching analysis.

To test:
1. Open the app and complete onboarding (or tap "See a sample analysis" to see demo results)
2. Grant camera permission
3. Record a short video (any movement works for testing — tennis court not required)
4. Wait for AI analysis (~30 seconds)
5. Review coaching results, grades, and drills

The app offers 3 free analyses before requiring a subscription.

Backend API: https://tennique-api-production.up.railway.app
No login required for basic use (guest mode available).
```

---

## App Store Screenshots

### Required sizes:
- iPhone 6.7" (1290 x 2796) — iPhone 15 Pro Max
- iPhone 6.1" (1179 x 2556) — iPhone 15 Pro

### Screenshot sequence (5-8 screens):
1. **Hero:** Phone showing skeleton overlay on tennis video — "AI Coach in Your Pocket"
2. **Recording:** Live recording screen with coaching cue overlay — "Real-Time Feedback While You Play"
3. **Results:** Coaching card with grade and hero cue — "Know Exactly What to Fix"
4. **Correction:** Skeleton morphing from red to green — "See the Fix, Not Just Hear It"
5. **Drill:** Practice plan with YouTube link — "Take It to the Court"
6. **Progress:** Progress dashboard with trends — "Track Your Improvement"

---

## Subscription Products (App Store Connect → In-App Purchases)

### Tennique Pro Monthly
- **Reference Name**: Tennique Pro Monthly
- **Product ID**: `tennique_pro_monthly`
- **Price**: $9.99/month
- **Subscription Group**: Tennique Pro
- **Description**: Unlimited AI analysis, priority processing, all coaching features

### Tennique Pro Annual
- **Reference Name**: Tennique Pro Annual
- **Product ID**: `tennique_pro_annual`
- **Price**: $59.99/year (saves 50%)
- **Subscription Group**: Tennique Pro
- **Description**: Everything in monthly, best value — save 50%

---

## Privacy Policy & Terms
- Privacy Policy: https://tennique.app/privacy
- Terms of Service: https://tennique.app/terms
- Support Email: support@tennique.app
