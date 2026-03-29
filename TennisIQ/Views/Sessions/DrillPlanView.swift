import SwiftUI

// MARK: - Drill Plan View
// Aggregates all drills from a session's stroke analyses into a single
// "take to the court" screen. Grouped by stroke, with a per-drill
// completion checkbox so the player can track their practice session.

struct DrillPlanView: View {
    let session: SessionModel
    private let theme = DesignSystem.current

    // Build drill items from all strokes in this session
    private var drillGroups: [DrillGroup] {
        let strokes = (session.strokeAnalyses ?? [])
            .filter { $0.strokeType != .unknown }
            .sorted { $0.timestamp < $1.timestamp }

        var groups: [DrillGroup] = []

        for stroke in strokes {
            var drills: [DrillItem] = []

            // Phase-level drills from PhaseBreakdown
            if let pb = stroke.phaseBreakdown {
                for (phase, detail) in pb.allPhases {
                    guard let detail, let drill = detail.drill, !drill.isEmpty else { continue }
                    // Only include phases that need work (not in_zone)
                    if detail.status != .inZone {
                        drills.append(DrillItem(
                            id: UUID(),
                            phase: phase.displayName,
                            description: drill,
                            cue: detail.improveCue,
                            priority: detail.status == .outOfZone ? .high : .medium
                        ))
                    }
                }
            }

            // nextRepsPlan as a top-level drill block
            if let plan = stroke.nextRepsPlan, !plan.isEmpty {
                drills.append(DrillItem(
                    id: UUID(),
                    phase: "Full Stroke",
                    description: plan,
                    cue: nil,
                    priority: .low
                ))
            }

            if !drills.isEmpty {
                // Sort: high priority first
                let sorted = drills.sorted { $0.priority.sortOrder < $1.priority.sortOrder }
                groups.append(DrillGroup(strokeType: stroke.strokeType, grade: stroke.grade, drills: sorted))
            }
        }

        return groups
    }

    private var totalDrills: Int {
        drillGroups.reduce(0) { $0 + $1.drills.count }
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if drillGroups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: Spacing.md) {
                        headerCard
                        ForEach(drillGroups) { group in
                            DrillGroupCard(group: group)
                        }
                        sessionTacticsCard
                        courtReminderCard
                    }
                    .padding(Spacing.md)
                    .padding(.bottom, Spacing.xxl)
                }
            }
        }
        .navigationTitle("Drill Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.accentMuted)
                    .frame(width: 52, height: 52)
                Image(systemName: "figure.tennis")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.accent)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Today's Practice Plan")
                    .font(AppFont.display(size: 18))
                    .foregroundStyle(theme.textPrimary)
                Text("\(totalDrills) drill\(totalDrills == 1 ? "" : "s") across \(drillGroups.count) stroke\(drillGroups.count == 1 ? "" : "s")")
                    .font(AppFont.body(size: 13))
                    .foregroundStyle(theme.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Session Tactical Notes

    @ViewBuilder
    private var sessionTacticsCard: some View {
        let notes = session.tacticalNotes.filter { !$0.isEmpty }
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Tactical Notes", systemImage: "lightbulb.fill")
                    .font(AppFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(theme.warning)

                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Circle()
                            .fill(theme.warning.opacity(0.7))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(note)
                            .font(AppFont.body(size: 14))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(theme.warning.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Court Reminder

    private var courtReminderCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(theme.textTertiary)
            Text("Check off each drill as you complete it on the court. Your progress is saved to this session.")
                .font(AppFont.body(size: 12))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfaceSecondary.opacity(0.5))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.success)
            VStack(spacing: Spacing.xs) {
                Text("No Drills Needed")
                    .font(AppFont.display(size: 22))
                    .foregroundStyle(theme.textPrimary)
                Text("All strokes are in zone.\nKeep up the great work!")
                    .font(AppFont.body(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Drill Group Card

private struct DrillGroupCard: View {
    let group: DrillGroup
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(strokeColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: group.strokeType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(strokeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.strokeType.displayName)
                        .font(AppFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text("\(group.drills.count) drill\(group.drills.count == 1 ? "" : "s")")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                // Grade badge
                Text(group.grade)
                    .font(AppFont.mono(size: 16, weight: .bold))
                    .foregroundStyle(gradeColor(group.grade))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.sm)
                            .fill(gradeColor(group.grade).opacity(0.12))
                    )
            }
            .padding(Spacing.md)

            Divider()
                .background(theme.surfaceSecondary)

            // Drill rows
            VStack(spacing: 0) {
                ForEach(group.drills) { drill in
                    DrillRow(drill: drill)
                    if drill.id != group.drills.last?.id {
                        Divider()
                            .background(theme.surfaceSecondary.opacity(0.5))
                            .padding(.leading, Spacing.xl + Spacing.md)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(theme.surfacePrimary)
        )
    }

    private var strokeColor: Color {
        switch group.strokeType {
        case .forehand: return theme.accent
        case .backhand: return theme.accentSecondary
        case .serve: return theme.success
        case .volley: return theme.warning
        case .unknown: return theme.textTertiary
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.prefix(1).uppercased() {
        case "A": return theme.success
        case "B": return theme.accent
        case "C": return theme.warning
        default: return theme.error
        }
    }
}

// MARK: - Drill Row

private struct DrillRow: View {
    let drill: DrillItem
    @State private var isCompleted = false
    @State private var isExpanded = false
    private let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    // Completion checkbox
                    Button(action: { withAnimation(.spring(response: 0.3)) { isCompleted.toggle() } }) {
                        ZStack {
                            Circle()
                                .strokeBorder(isCompleted ? theme.success : theme.surfaceSecondary, lineWidth: 2)
                                .frame(width: 24, height: 24)
                            if isCompleted {
                                Circle()
                                    .fill(theme.success)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(theme.textOnAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 1)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack(spacing: Spacing.xs) {
                            Text(drill.phase)
                                .font(AppFont.body(size: 13, weight: .semibold))
                                .foregroundStyle(isCompleted ? theme.textTertiary : theme.textPrimary)
                                .strikethrough(isCompleted)

                            priorityBadge
                        }

                        Text(drill.description)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(isCompleted ? theme.textTertiary : theme.textSecondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(Spacing.md)
            }
            .buttonStyle(.plain)

            // Expanded: show coaching cue
            if isExpanded, let cue = drill.cue, !cue.isEmpty {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                    Text("Cue: \(cue)")
                        .font(AppFont.body(size: 12, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.sm)
                .padding(.leading, 36) // align with drill text
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        if drill.priority == .high {
            Text("PRIORITY")
                .font(AppFont.body(size: 10, weight: .bold))
                .foregroundStyle(theme.error)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm)
                        .fill(theme.error.opacity(0.12))
                )
        }
    }
}

// MARK: - Data Models

struct DrillGroup: Identifiable {
    let id = UUID()
    let strokeType: StrokeType
    let grade: String
    let drills: [DrillItem]
}

struct DrillItem: Identifiable {
    let id: UUID
    let phase: String
    let description: String
    let cue: String?
    let priority: DrillPriority
}

enum DrillPriority {
    case high, medium, low

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}
