import SwiftUI

/// Scheme 3: "Rally" — Bold Sport-Tech
/// Navy base + hot coral for problems + cyan for correct form. Energetic data-driven aesthetic.
struct RallyTheme: AppTheme {
    let name = "Rally"

    // Backgrounds
    let background = Color(hex: "0C1222")
    let surfacePrimary = Color(hex: "111827")
    let surfaceSecondary = Color(hex: "1A2236")
    let surfaceElevated = Color(hex: "222D45")

    // Accents — coral energy + cyan data
    let accent = Color(hex: "FF5C5C")
    let accentSecondary = Color(hex: "00D4FF")
    let accentMuted = Color(hex: "FF5C5C").opacity(0.12)

    // Text
    let textPrimary = Color(hex: "F0F4FF")
    let textSecondary = Color(hex: "8892A8")
    let textTertiary = Color(hex: "4A5568")
    let textOnAccent = Color(hex: "FFFFFF")

    // Semantic
    let success = Color(hex: "00D4FF")
    let warning = Color(hex: "FFB547")
    let error = Color(hex: "FF5C5C")

    // Overlay — dual-tone skeleton (coral = problem, cyan = correct)
    let skeletonStroke = Color(hex: "00D4FF")
    let skeletonCorrect = Color(hex: "00D4FF")
    let skeletonWarning = Color(hex: "FF5C5C")
    let angleAnnotation = Color(hex: "FFB547")
    let trajectoryLine = Color(hex: "00D4FF").opacity(0.7)

    // Typography
    let displayFont = "SpaceMono-Bold"
    let bodyFont = "Satoshi-Regular"
    let monoFont = "SpaceMono-Regular"
}
