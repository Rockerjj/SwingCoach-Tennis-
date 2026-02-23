import SwiftUI

/// Scheme 2: "Grand Slam" — Refined with Roland Garros clay tones
/// Warm off-white + Wimbledon green + Championship gold + French Open clay
/// Tasteful, muted, satisfying, calming.
struct GrandSlamTheme: AppTheme {
    let name = "Grand Slam"

    // Backgrounds — warm cream
    let background = Color(hex: "FAF8F5")
    let surfacePrimary = Color(hex: "FFFFFF")
    let surfaceSecondary = Color(hex: "F3EFE8")
    let surfaceElevated = Color(hex: "FFFFFF")

    // Accents — Wimbledon green (authority) + Championship gold (warmth) + Roland Garros clay (energy)
    let accent = Color(hex: "2D5F45")
    let accentSecondary = Color(hex: "BFA14A")
    let accentMuted = Color(hex: "2D5F45").opacity(0.06)

    // Text
    let textPrimary = Color(hex: "1F2421")
    let textSecondary = Color(hex: "5A6058")
    let textTertiary = Color(hex: "8E9189")
    let textOnAccent = Color(hex: "FAF8F5")

    // Semantic — calming, muted score palette
    let success = Color(hex: "5E8E6B")     // Sage green — mastery
    let warning = Color(hex: "BFA14A")     // Warm gold — developing
    let error = Color(hex: "C4876B")       // Clay salmon — needs attention

    // Extended score palette (for score bars in views)
    static let scoreExcellent = Color(hex: "5E8E6B")   // 8-10
    static let scoreGood = Color(hex: "7EA882")         // 7
    static let scoreFair = Color(hex: "BFA14A")         // 5-6
    static let scoreNeedsWork = Color(hex: "C4876B")    // 3-4
    static let scorePoor = Color(hex: "B07272")         // 1-2

    // Roland Garros clay as a named color
    static let clay = Color(hex: "C4876B")
    static let goldMuted = Color(hex: "BFA14A").opacity(0.08)
    static let clayMuted = Color(hex: "C4876B").opacity(0.07)

    // Overlay — clean white skeleton, sage correct, clay warning
    let skeletonStroke = Color(hex: "FFFFFF").opacity(0.92)
    let skeletonCorrect = Color(hex: "5E8E6B")
    let skeletonWarning = Color(hex: "C4876B")
    let angleAnnotation = Color(hex: "BFA14A")
    let trajectoryLine = Color(hex: "2D5F45")

    // Typography — editorial luxury
    let displayFont = "Fraunces-Bold"
    let bodyFont = "Outfit-Regular"
    let monoFont = "JetBrainsMono-Medium"
}
