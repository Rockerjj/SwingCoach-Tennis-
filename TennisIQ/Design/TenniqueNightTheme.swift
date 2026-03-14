import SwiftUI

/// Dark Whoop-style theme: dark charcoal + bright green accents
/// Premium health app aesthetic with dark forest green nav
struct TenniqueNightTheme: AppTheme {
    let name = "Tennique Night"

    // Backgrounds — dark charcoal
    let background = Color(hex: "1A1A1A")
    let surfacePrimary = Color(hex: "242424")
    let surfaceSecondary = Color(hex: "2E2E2E")
    let surfaceElevated = Color(hex: "303030")

    // Accents — subtle cool white palette
    let accent = Color(hex: "E2E8F0")
    let accentSecondary = Color(hex: "CBD5E1")
    let accentMuted = Color(hex: "E2E8F0").opacity(0.10)

    // Text
    let textPrimary = Color(hex: "F9FAFB")
    let textSecondary = Color(hex: "9CA3AF")
    let textTertiary = Color(hex: "6B7280")
    let textOnAccent = Color(hex: "FFFFFF")

    // Semantic
    let success = Color(hex: "22C55E")
    let warning = Color(hex: "F59E0B")
    let error = Color(hex: "EF4444")

    // Nav / video area
    static let navBackground = Color(hex: "1B4332")

    // Overlay
    let skeletonStroke = Color.white.opacity(0.92)
    let skeletonCorrect = Color(hex: "22C55E")
    let skeletonWarning = Color(hex: "EF4444")
    let angleAnnotation = Color(hex: "E2E8F0")
    let trajectoryLine = Color(hex: "4ADE80")

    // Typography — system SF Pro
    let displayFont = ""
    let bodyFont = ""
    let monoFont = ""
}
