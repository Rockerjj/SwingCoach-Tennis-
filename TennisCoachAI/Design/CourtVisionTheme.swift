import SwiftUI

/// Scheme 1: "Court Vision" — Dark Athletic Precision
/// Dark charcoal base + electric lime accent. Pro video tool meets sports analytics.
struct CourtVisionTheme: AppTheme {
    let name = "Court Vision"

    // Backgrounds
    let background = Color(hex: "0A0A0F")
    let surfacePrimary = Color(hex: "141419")
    let surfaceSecondary = Color(hex: "1C1C24")
    let surfaceElevated = Color(hex: "24242E")

    // Accents — tennis ball electric lime
    let accent = Color(hex: "C8FF00")
    let accentSecondary = Color(hex: "3B82F6")
    let accentMuted = Color(hex: "C8FF00").opacity(0.15)

    // Text
    let textPrimary = Color(hex: "F0F0F5")
    let textSecondary = Color(hex: "9898A8")
    let textTertiary = Color(hex: "5C5C6E")
    let textOnAccent = Color(hex: "0A0A0F")

    // Semantic
    let success = Color(hex: "34D399")
    let warning = Color(hex: "FBBF24")
    let error = Color(hex: "E85D3A")

    // Overlay — neon lime skeleton
    let skeletonStroke = Color(hex: "C8FF00")
    let skeletonCorrect = Color(hex: "34D399")
    let skeletonWarning = Color(hex: "E85D3A")
    let angleAnnotation = Color(hex: "C8FF00").opacity(0.9)
    let trajectoryLine = Color(hex: "3B82F6")

    // Typography
    let displayFont = "DMSans-Bold"
    let bodyFont = "IBMPlexSans"
    let monoFont = "JetBrainsMono-Medium"
}
