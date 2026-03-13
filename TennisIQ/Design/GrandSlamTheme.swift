import SwiftUI

/// Updated theme: White + Dark Forest Green — clean, minimal, premium
/// Inspired by Whoop/premium health app aesthetic
struct GrandSlamTheme: AppTheme {
    let name = "Grand Slam"

    // Backgrounds — pure white
    let background = Color(hex: "FFFFFF")
    let surfacePrimary = Color(hex: "FFFFFF")
    let surfaceSecondary = Color(hex: "F8F9FA")
    let surfaceElevated = Color(hex: "FFFFFF")

    // Accents — dark forest green
    let accent = Color(hex: "1B4332")
    let accentSecondary = Color(hex: "2D6A4F")
    let accentMuted = Color(hex: "1B4332").opacity(0.06)

    // Text
    let textPrimary = Color(hex: "1A1A1A")
    let textSecondary = Color(hex: "6B7280")
    let textTertiary = Color(hex: "9CA3AF")
    let textOnAccent = Color(hex: "FFFFFF")

    // Semantic — brighter, cleaner
    let success = Color(hex: "16A34A")
    let warning = Color(hex: "D97706")
    let error = Color(hex: "DC2626")

    // Extended score palette (for score bars in views)
    static let scoreExcellent = Color(hex: "16A34A")   // 8-10
    static let scoreGood = Color(hex: "22C55E")         // 7
    static let scoreFair = Color(hex: "D97706")         // 5-6
    static let scoreNeedsWork = Color(hex: "EA580C")    // 3-4
    static let scorePoor = Color(hex: "DC2626")         // 1-2

    // Overlay — clean white skeleton, green correct, red warning
    let skeletonStroke = Color(hex: "FFFFFF").opacity(0.92)
    let skeletonCorrect = Color(hex: "16A34A")
    let skeletonWarning = Color(hex: "DC2626")
    let angleAnnotation = Color(hex: "D97706")
    let trajectoryLine = Color(hex: "1B4332")

    // Typography — system fonts (Inter-like)
    let displayFont = ""
    let bodyFont = ""
    let monoFont = ""
}
