import SwiftUI

// MARK: - Theme Protocol

protocol AppTheme {
    var name: String { get }

    // Backgrounds
    var background: Color { get }
    var surfacePrimary: Color { get }
    var surfaceSecondary: Color { get }
    var surfaceElevated: Color { get }

    // Accents
    var accent: Color { get }
    var accentSecondary: Color { get }
    var accentMuted: Color { get }

    // Text
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var textOnAccent: Color { get }

    // Semantic
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }

    // Overlay-specific
    var skeletonStroke: Color { get }
    var skeletonCorrect: Color { get }
    var skeletonWarning: Color { get }
    var angleAnnotation: Color { get }
    var trajectoryLine: Color { get }

    // Typography
    var displayFont: String { get }
    var bodyFont: String { get }
    var monoFont: String { get }
}

// MARK: - Design System Singleton

final class DesignSystem: ObservableObject {
    static let shared = DesignSystem()

    @Published var currentTheme: AppTheme = GrandSlamTheme()

    static var current: AppTheme {
        shared.currentTheme
    }

    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
}

// MARK: - Typography Helpers

struct AppFont {
    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name = DesignSystem.current.displayFont
        if name.isEmpty {
            return .system(size: size, weight: weight, design: .default)
        }
        return .custom(name, size: size).weight(weight)
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name = DesignSystem.current.bodyFont
        if name.isEmpty {
            return .system(size: size, weight: weight, design: .default)
        }
        return .custom(name, size: size).weight(weight)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        let name = DesignSystem.current.monoFont
        if name.isEmpty {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        return .custom(name, size: size).weight(weight)
    }
}

// MARK: - Spacing Scale

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}

// MARK: - Corner Radius Scale

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}
