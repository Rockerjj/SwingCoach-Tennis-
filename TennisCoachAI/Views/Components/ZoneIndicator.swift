import SwiftUI

struct ZoneIndicator: View {
    let status: ZoneStatus
    var style: Style = .badge

    enum Style {
        case badge
        case dot
    }

    private let theme = DesignSystem.current

    var body: some View {
        switch style {
        case .badge:
            Text(status.displayLabel)
                .font(AppFont.body(size: 12, weight: .semibold))
                .foregroundStyle(zoneColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(Capsule().fill(zoneColor.opacity(0.15)))
        case .dot:
            Circle()
                .fill(zoneColor)
                .frame(width: 8, height: 8)
        }
    }

    private var zoneColor: Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }
}
