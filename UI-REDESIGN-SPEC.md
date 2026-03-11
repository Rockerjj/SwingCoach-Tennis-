# Tennique UI Redesign Spec
**Status:** Ready to implement | **Author:** AI audit (March 11, 2026)
**References:** test-data/first-run-screenshots/ + references/sevensix-competitor/

---

## Executive Summary

The analysis engine works. The UI looks like a debug visualizer. The redesign goal is to make every screen feel like a premium $59/mo coaching product — not a research prototype. Every change below is grounded in what we saw in the first-run screenshots and what competitors do better.

---

## 🔴 P0 — Fix Before Anyone Sees This

### 1. "Auto Slow" button text is broken
**Problem:** "Aut / o / Slo / w" wraps inside a fixed-size circle. Embarrassing.
**Fix:** Replace text label with SF Symbol. Use `gauge.with.dots.needle.bottom.50percent` or custom. Never text in a fixed circle.

```swift
// BEFORE
Text("Auto Slow")
// AFTER
Image(systemName: "slowmo")
    .font(.system(size: 16, weight: .semibold))
```

### 2. Debug numbers on video
**Problem:** "0, 0, 2, 5, x" / "1, x" rendering on video frame. Users see this.
**Fix:** Find and remove the debug overlay render call. Search for any `.overlay` or `drawText` in PlaybackView/OverlayRenderer that isn't a real UI element.

### 3. No color on grades or metric pills
**Problem:** A "D" and an "F" look identical. An elbow at 84° (ideal: 155°) looks the same as one at 160°.
**Fix:** Color-code everything.

```swift
func gradeColor(_ grade: String) -> Color {
    switch grade {
    case "A", "A+", "A-": return Color(hex: "#22c55e")   // green
    case "B", "B+", "B-": return Color(hex: "#84cc16")   // lime
    case "C", "C+", "C-": return Color(hex: "#eab308")   // yellow
    case "D", "D+", "D-": return Color(hex: "#f97316")   // orange
    case "F":              return Color(hex: "#ef4444")   // red
    default:               return Color.gray
    }
}

func metricColor(value: Double, idealMin: Double, idealMax: Double) -> Color {
    let pct = (value - idealMin) / (idealMax - idealMin)
    if value >= idealMin && value <= idealMax { return .green }
    let delta = min(abs(value - idealMin), abs(value - idealMax))
    if delta < 15 { return .yellow }
    if delta < 30 { return .orange }
    return .red
}
```

---

## 🟠 P1 — Ship-Blocking Polish

### 4. Skeleton overlay — professional look
**Problem:** Flat teal/green lines with yellow dots. No glow, no contrast adaptation, no depth. Looks like a wireframe debug tool.

**Target look:** Neon-luminous, thin white core with colored outer glow. Joint dots sized by importance. Color-coded to coaching quality (green = good position, orange = needs work, red = off).

```swift
// In OverlayRenderer — skeleton line style
func drawBone(from: CGPoint, to: CGPoint, quality: BoneQuality, context: CGContext) {
    // Outer glow
    context.setStrokeColor(quality.color.withAlphaComponent(0.25).cgColor)
    context.setLineWidth(8)
    context.strokePath()
    
    // Core line
    context.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
    context.setLineWidth(2)
    context.strokePath()
}

func drawJoint(at point: CGPoint, importance: JointImportance, quality: BoneQuality, context: CGContext) {
    let radius: CGFloat = importance == .primary ? 7 : 4
    // Glow ring
    context.setFillColor(quality.color.withAlphaComponent(0.3).cgColor)
    context.fillEllipse(in: CGRect(center: point, radius: radius + 3))
    // White core
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(center: point, radius: radius))
}
```

Primary joints (wrist, elbow, shoulder, hip, knee): larger, colored by coaching quality
Secondary joints (nose, ankle): smaller, white only

### 5. Swing path — spline not dots
**Problem:** Series of translucent green dots. Faint, hard to read, no direction.

**Target look:** Smooth Catmull-Rom spline, gradient from blue (start) → white → yellow (contact point), fading tail, arrowhead at contact.

```swift
// Gradient path from start to contact
let colors = [
    UIColor.systemBlue.withAlphaComponent(0.3),
    UIColor.white.withAlphaComponent(0.8),
    UIColor.systemYellow,
]
// Apply gradient along the path using CGGradient
// Add a filled triangle arrowhead at the contact point
```

### 6. Metric pills — redesign as full cards
**Problem:** Horizontally scrolling pills get truncated. No color. No visual encoding.

**Replace with:** Vertical stack of compact metric cards below video.

```
┌─────────────────────────────────────┐
│ 🔴  Elbow Angle          84°        │
│     Ideal: 155–175°   ▼ 71° below  │
│ ████░░░░░░░░░░░░░░░░░░░░ 28%       │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 🟡  Shoulder Rotation    45°        │
│     Ideal: 60–90°     ▼ 15° below  │
│ ████████████░░░░░░░░░░░ 65%        │
└─────────────────────────────────────┘
```

Each card: metric name, measured value (large, color-coded), ideal range, delta, progress bar.
Use `LazyVStack` with `ScrollView(.vertical)` replacing the current horizontal scroll.

### 7. Stroke timeline — bigger, color-coded, labeled
**Problem:** Small square tiles, no color coding, arrows not explained, first/last tile cut off.

**Replace with:**
```
STROKE TIMELINE  •  6 strokes  •  Avg: D  •  Best: D

[← BH]  [→ FH]  [→ FH]  [→ FH]  [← BH]  [→ FH]
   D        D       F        D       D-       D
(orange) (orange) (red)  (orange)(orange)(orange)
```

Design specs:
- Pill shape, wider (80pt min width)
- Background color: grade-appropriate tint (red for F, orange for D, etc.)
- Text: stroke type abbreviation + arrow direction, grade below in bold
- Selected state: solid color + scale(1.05)
- Add summary header: "6 strokes • Avg: D • Best: D"
- Use `ScrollViewReader` + `.scrollTo()` for snap-to-stroke

### 8. Snap-to-stroke (missing feature)
**Problem:** Tapping a stroke tile doesn't jump the video to that stroke's moment.

**Fix:** `PlaybackViewModel` needs to seek video to `stroke.contactTimestamp` on tap.

```swift
func selectStroke(_ stroke: StrokeResult) {
    selectedStrokeIndex = stroke.index
    let targetTime = CMTime(seconds: stroke.timestamp, preferredTimescale: 600)
    player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
}
```

### 9. Video controls — consolidated HUD
**Problem:** 5 floating elements with 3 different styles. "Auto Slow" text wraps.

**Replace with:** Two zones:
1. **Top HUD strip** (semi-transparent blur): Back button (left), session date (center), Share (right)
2. **Bottom control bar** (semi-transparent blur): Play/Pause | Scrubber | Speed (0.25x/0.5x/1x) | Layers toggle

Remove: STROKE badge floating on video (confusing), separate Path/Overlay/AutoSlow floating buttons.

```swift
// Bottom control bar
HStack {
    PlayPauseButton()
    VideoScrubber(progress: $progress)
    SpeedButton(speed: $playbackSpeed)
    LayersMenu(showSkeleton: $showSkeleton, showPath: $showPath)
}
.padding()
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 20))
.padding(.horizontal)
```

---

## 🟡 P2 — Quality of Life

### 10. Session summary header
Add above the timeline:
```
Session Grade: D  •  6 Strokes  •  Mar 10, 2026
Focus: Elbow extension at contact point
```

### 11. Coaching cards below metrics
After the metric cards, add collapsible coaching cards:
```
🎯 TOP PRIORITY
   "Increase arm extension at contact. Your average 
    extension is 28% of ideal. Focus drill: 
    Extended contact wall rally, 20 mins/day."
    
📚 DRILL: Extended Contact Wall Rally
   [Expand for full instructions]
```

These already exist in the GPT response — just need to be surfaced in the UI.

### 12. Session history list — add thumbnail + grade
Current session list is just text. Add:
- Video thumbnail (first frame)
- Overall grade badge (color-coded)
- Stroke count + duration
- "Improved since last session" indicator

### 13. Tab bar — Record as primary FAB
Move Record out of tab bar into a prominent center FAB button:
```
[Sessions] [Progress]  [+Record]  [Compare] [Profile]
                         (large)
```

---

## Design System Tokens

```swift
// Colors
let tenniquePrimary = Color(hex: "#00D4FF")    // Electric blue (active/accent)
let tenniqueBg = Color(hex: "#0A0E1A")         // Near-black background
let tenniqueCard = Color(hex: "#111827")       // Card background
let tenniqueBorder = Color(hex: "#1F2937")     // Subtle borders

// Grade colors
let gradeA = Color(hex: "#22C55E")
let gradeB = Color(hex: "#84CC16")
let gradeC = Color(hex: "#EAB308")
let gradeD = Color(hex: "#F97316")
let gradeF = Color(hex: "#EF4444")

// Typography
let heroGrade = Font.system(size: 64, weight: .black, design: .rounded)
let sectionHeader = Font.system(size: 11, weight: .semibold).tracking(1.5)
let metricValue = Font.system(size: 28, weight: .bold, design: .rounded)
let metricLabel = Font.system(size: 12, weight: .medium)
let cardBody = Font.system(size: 14, weight: .regular)
```

---

## Files to Touch

| File | Changes |
|------|---------|
| `OverlayRenderer.swift` | Glow skeleton lines, colored joints, spline path, remove debug numbers |
| `PlaybackView.swift` | Consolidated HUD, remove floating buttons |
| `PlaybackViewModel.swift` | Add `selectStroke()` seek method |
| `AnalysisResultsView.swift` | Full redesign — session header, metric cards, coaching cards |
| `StrokeTimelineView.swift` | New: larger pills, color-coded, summary header |
| `SessionListView.swift` | Add thumbnails + grade badges |
| `DesignSystem.swift` | New: color tokens, grade colors, typography scale |

---

## Implementation Order (Day 1)

1. `DesignSystem.swift` — tokens first, everything references these
2. Remove debug numbers (30 min)
3. Fix "Auto Slow" button (15 min)
4. Color-code grades in timeline + result cards (1 hour)
5. Snap-to-stroke seek (1 hour)
6. Metric cards redesign (2 hours)
7. Skeleton overlay glow effect (2 hours)
8. Swing path spline + gradient (2 hours)
9. Consolidated video controls HUD (2 hours)
10. Session summary header (1 hour)

**Target: One full day to go from "debug visualizer" to "premium coaching app"**

---

*Spec written March 11, 2026 — ready for morning implementation session with Josh*
