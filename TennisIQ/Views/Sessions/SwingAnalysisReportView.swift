import SwiftUI

struct SwingAnalysisReportView: View {
    let categories: [AnalysisCategory]

    @State private var reportMode: ReportMode = .standard
    private let theme = DesignSystem.current

    enum ReportMode: String, CaseIterable {
        case standard = "Standard"
        case custom = "Custom"
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Picker("Mode", selection: $reportMode) {
                ForEach(ReportMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.md)

            List {
                ForEach(categories) { category in
                    CategoryCard(category: category)
                        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(theme.background)
    }
}

private struct CategoryCard: View {
    let category: AnalysisCategory

    @State private var isExpanded = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.sm) {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(zoneBgColor)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: categoryIcon)
                                .font(.system(size: 18))
                                .foregroundStyle(zoneColor)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(category.name)
                            .font(AppFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text(category.description)
                            .font(AppFont.body(size: 12))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer()

                    ZoneIndicator(status: category.status, style: .badge)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Divider().foregroundStyle(theme.surfaceSecondary)

                    ForEach(category.subchecks) { subcheck in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            ZoneIndicator(status: subcheck.status, style: .dot)

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(subcheck.checkpoint)
                                    .font(AppFont.body(size: 13, weight: .medium))
                                    .foregroundStyle(theme.textPrimary)

                                Text(subcheck.result)
                                    .font(AppFont.body(size: 12))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                    }
                }
                .padding(.bottom, Spacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private var categoryIcon: String {
        switch category.name.lowercased() {
        case let n where n.contains("posture"): return "figure.stand"
        case let n where n.contains("swing"): return "arrow.up.forward"
        case let n where n.contains("foot"): return "shoeprints.fill"
        case let n where n.contains("contact"): return "target"
        case let n where n.contains("follow"): return "arrow.turn.up.right"
        case let n where n.contains("spine"): return "arrow.up.and.down"
        default: return "checkmark.circle"
        }
    }

    private var zoneColor: Color {
        switch category.status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }

    private var zoneBgColor: Color {
        switch category.status {
        case .inZone: return theme.success.opacity(0.12)
        case .warning: return theme.warning.opacity(0.12)
        case .outOfZone: return theme.error.opacity(0.1)
        }
    }
}
