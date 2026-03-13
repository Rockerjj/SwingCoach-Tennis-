# Tennique Prototype — Full UI Redesign Spec

## Design Direction

**Theme:** White + dark green. Clean, minimal, premium. Think Whoop but lighter.
**Vibe:** INSPO 4 (score ring, card-based, generous spacing) + INSPO 5 (bar chart, pills, bold numbers)
**NO emojis anywhere.** Use SVG icons or simple geometric shapes.
**NO gimmicky elements.** Everything should feel like a premium health/fitness app.

Reference images at: `../references/tennique-inspo/` (inspo-1 through inspo-6)
- INSPO 4 (score-ring) and INSPO 5 (bar-chart) are PRIMARY references
- INSPO 2 (green-cards) and INSPO 3 (white-metrics) for card/metric layout
- INSPO 1 (dark-dashboard) — use as light-inverted version of that clean aesthetic
- INSPO 6 (analytics-grid) — data viz patterns only

## Color Palette

```css
:root {
  --bg: #FFFFFF;
  --surface: #F8F9FA;           /* card backgrounds — very light gray */
  --surface-hover: #F0F2F4;
  --text: #1A1A1A;              /* primary text — near black */
  --text-secondary: #6B7280;    /* secondary — medium gray */
  --text-muted: #9CA3AF;        /* timestamps, labels */
  --accent: #1B4332;            /* dark forest green — primary accent */
  --accent-light: #2D6A4F;      /* slightly lighter green */
  --accent-bg: rgba(27,67,50,0.06); /* green tint background */
  --accent-bg-strong: rgba(27,67,50,0.12);
  --success: #16A34A;           /* good/in-zone */
  --success-bg: rgba(22,163,74,0.08);
  --warning: #D97706;           /* adjust/needs work */
  --warning-bg: rgba(217,119,6,0.08);
  --error: #DC2626;             /* out of zone */
  --error-bg: rgba(220,38,38,0.08);
  --border: #E5E7EB;            /* subtle borders */
  --border-light: #F3F4F6;      /* very subtle dividers */
  --skeleton: rgba(100,180,220,0.7);
  --skeleton-glow: rgba(100,180,220,0.3);
}
```

## Scope

**DO NOT touch the video player area** (keep the dark green video section with skeleton overlay, badges, and controls as-is).
**REDESIGN everything below the video:** stroke timeline, phase breakdown, session summary, swing analysis, coaching cards, and pro comparison.

## Font

Switch from Outfit + Fraunces to a cleaner system:
- **Primary:** `'Inter', -apple-system, system-ui, sans-serif` (import Inter from Google Fonts)
- **Mono:** `'SF Mono', 'JetBrains Mono', monospace`
- **NO serif font** — kill Fraunces entirely

## Stroke Timeline (shot selector)

Current: Chips with emojis (→, ←, ↑) and colored grade badges.
**Redesign:**
- Clean horizontal scrollable pills on white bg
- Each pill: `Forehand 1` or `Backhand 1` in clean sans-serif
- Active pill: dark green background (#1B4332), white text
- Inactive pills: white bg with subtle border (#E5E7EB), dark text
- Grade badge: Small, right-aligned inside pill. Green text for A/B, amber for C, red for D/F. NO colored background — just the letter.
- Pill height: 40px, proper 44px touch target with padding
- Add a subtle fade/gradient on right edge to indicate scroll affordance

## Phase Breakdown

Current: Colored dots with numbers + text labels below. "NEW" tag.
**Redesign:**
- Remove "NEW" tag
- Clean horizontal row of **small circles** connected by a thin line
- Each circle: 28px, white fill, subtle border
- Score number inside each circle in the accent color
- Selected circle: dark green fill (#1B4332), white number, slightly larger (32px)
- Phase name below: 10px, uppercase, letter-spaced, muted gray
- Color coding via a subtle ring/border only:
  - 8-10: green border
  - 6-7: amber border  
  - 1-5: red border
- Fix abbreviations: "Forward Swing", "Follow-Through", "Recovery"

### Phase Detail Card

When a phase is selected, show detail card below:
- **White card** with very subtle border and shadow (`0 1px 3px rgba(0,0,0,0.04)`)
- **Title**: Bold, 16px, dark text + score in a clean circle (right-aligned)
- **Subtitle**: "Racket take-back · t=0.42s" in muted text
- **Metrics row**: Clean pills with dot + label + value. e.g., `● Elbow: 142°` — green dot for good, amber for warn
- **Coaching Cue**: Light green background card (#accent-bg), left border accent (#1B4332), clean text. NO label above — just the coaching text with a small book/lightbulb SVG icon inline.

## Session Summary

Current: Big letter grade in colored box + meta + "Top Priority" callout + Swing Analysis with emoji icons.
**Redesign inspired by INSPO 4 (score ring):**

### Overall Score Section
- **Large circular progress ring** (like INSPO 4's "72 Good")
  - Ring: 120px diameter, stroke-width 8px, dark green fill for score percentage
  - Center: Big bold number "72.5" in 32px Inter bold
  - Below ring: "Overall Score" label in muted text
  - Below that: Letter grade "B" in small green pill
- **Meta line** below: "4 strokes · 2:35 session" in muted text, centered

### Top Priority Card
- Clean white card with left green border (3px solid #1B4332)
- "PRIORITY" label small, uppercase, green
- Priority text in 14px, normal weight

### Swing Analysis List
Remove "NEW" tag. Remove ALL emojis from icons.

Each row:
- **Icon**: 32px circle with a simple 1-color SVG icon (e.g., body posture silhouette, racket path line, footprint, target, arm motion, spine, impact). Use simple geometric/line icons, NOT emojis.
  - Green bg circle for "In Zone"
  - Amber bg circle for "Adjust"
  - Red bg circle for "Out of Zone"
- **Name**: 14px, semibold, dark text
- **Description**: 12px, muted gray
- **Status badge**: Right-aligned pill
  - "In Zone" = green text on green-bg pill
  - "Adjust" = amber text on amber-bg pill
  - "Out of Zone" = red text on red-bg pill
  - Add a secondary shape indicator (e.g., ✓ for In Zone, – for Adjust, ✕ for Out) for colorblind accessibility

Row height: 56px. Subtle bottom border between rows.

## Compare to Pro

**Remove the Compare to Pro button entirely.** It's not functional in the real app yet. Delete the button AND the bottom sheet.

## Coaching Cards (Forehand #1, #2, etc.)

Current: Expandable cards with emoji arrows, grade rationale as text wall.
**Redesign:**

### Card Header (collapsed)
- Clean row: "Forehand #1" (bold, 14px) + timestamp "t=34.2s" (mono, muted) + grade "B" (green text) + chevron icon (›)
- No emojis. Just text.

### Card Body (expanded)
- **Grade Rationale**: 
  - Bold key numbers inline: "contact point was slightly behind ideal — unit turn at **~60°** vs ideal **90°+**"
  - Clean paragraph, 13px, good line-height (1.6)
  
- **Improvement Plan**:
  - Structured as a **numbered list**, NOT a paragraph
  - Each phase on its own line with time:
    ```
    1. Shadow swings — full unit turn (5 min)
    2. Drop-feed forehands — contact in front of lead hip (10 min)  
    3. Cross-court rally with target (5 min)
    ```
  - Clean divider between rationale and plan

## Global Rules

1. **NO emojis anywhere** — replace all with SVG icons or remove entirely
2. **White background** (#FFFFFF) for page, light gray (#F8F9FA) for cards
3. **One accent color**: dark green (#1B4332) for buttons, active states, accents
4. **Card style**: subtle border (#E5E7EB) + tiny shadow. Border-radius: 12px.
5. **Spacing**: Generous. 16px padding in cards, 12px gaps between sections.
6. **Typography**: Inter only. Weights: 400 (body), 500 (labels), 600 (headings), 700 (big numbers)
7. **Touch targets**: 44px minimum for all interactive elements
8. **Phone frame** on desktop: keep the phone mockup wrapper but change outer bg from green (#2D5F45) to subtle gray (#F0F2F4)
9. **Scrollbar**: hidden on webkit (already done)
10. **Transitions**: subtle 0.2s ease on hover/active states
