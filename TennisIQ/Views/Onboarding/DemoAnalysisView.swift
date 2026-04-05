import SwiftUI

/// A standalone demo analysis view that shows pre-baked results
/// without requiring a video URL or SwiftData session.
/// Used during onboarding to show users the full analysis experience.
struct DemoAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    private let theme = DesignSystem.current
    private let analysis = DemoSession.analysisResponse
    private let ctaTitle: String?
    private let onComplete: (() -> Void)?
    @State private var selectedStroke: StrokeResult?
    @State private var selectedPhase: SwingPhase?
    @State private var showPhaseDetail = false
    @State private var appearAnimation = false

    init(
        ctaTitle: String? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.ctaTitle = ctaTitle
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        demoBanner
                        sessionGradeCard
                        topPriorityCard
                        strokeCards
                        tacticalNotesCard
                        if let ctaTitle {
                            onboardingFooter(ctaTitle: ctaTitle)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationTitle("Demo Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if onComplete == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            .sheet(item: $selectedStroke) { stroke in
                DemoStrokeDetailView(stroke: stroke)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appearAnimation = true
                }
            }
        }
    }

    // MARK: - Demo Banner

    private var demoBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)

            Text("This is a demo analysis — record your own session to get personalized coaching!")
                .font(AppFont.body(size: 13))
                .foregroundStyle(theme.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 10)
    }

    // MARK: - Session Grade

    private var sessionGradeCard: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Session Grade")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textTertiary)
                    Text(analysis.sessionGrade)
                        .font(AppFont.display(size: 48, weight: .bold))
                        .foregroundStyle(gradeColor(analysis.sessionGrade))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xxs) {
                    Text("Mechanics Score")
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textTertiary)
                    Text("\(Int(analysis.overallMechanicsScore))%")
                        .font(AppFont.display(size: 28, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                }
            }

            Text(analysis.sessionSummary)
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(Spacing.lg)
        .background(theme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Top Priority

    private var topPriorityCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.warning)
                Text("TOP PRIORITY")
                    .font(AppFont.mono(size: 11, weight: .bold))
                    .foregroundStyle(theme.warning)
            }

            Text(analysis.topPriority)
                .font(AppFont.body(size: 15))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(3)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 20)
    }

    // MARK: - Stroke Cards

    private var strokeCards: some View {
        VStack(spacing: Spacing.md) {
            ForEach(analysis.strokesDetected) { stroke in
                DemoStrokeCard(stroke: stroke) {
                    selectedStroke = stroke
                }
            }
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
    }

    // MARK: - Tactical Notes

    private var tacticalNotesCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
                Text("Tactical Notes")
                    .font(AppFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }

            ForEach(analysis.tacticalNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 6, height: 6)
                        .offset(y: 6)
                    Text(note)
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
    }

    private func onboardingFooter(ctaTitle: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Button(action: completeDemoFlow) {
                Text(ctaTitle)
                    .font(AppFont.body(size: 17, weight: .semibold))
                    .foregroundStyle(theme.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }

            Text("Next, sign in and upload a real session to get coaching tied to your own swing.")
                .font(AppFont.body(size: 13))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)
        }
        .opacity(appearAnimation ? 1 : 0)
        .offset(y: appearAnimation ? 0 : 30)
    }

    // MARK: - Helpers

    private func completeDemoFlow() {
        onComplete?()
        dismiss()
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.prefix(1) {
        case "A": return theme.success
        case "B": return theme.accent
        case "C": return theme.warning
        default: return theme.error
        }
    }
}

// MARK: - Stroke Card

struct DemoStrokeCard: View {
    let stroke: StrokeResult
    let onTap: () -> Void
    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Spacing.md) {
                HStack {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: stroke.type.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(theme.accent)
                        Text(stroke.type.displayName)
                            .font(AppFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                    }

                    Spacer()

                    Text(stroke.grade)
                        .font(AppFont.display(size: 24, weight: .bold))
                        .foregroundStyle(gradeColor(stroke.grade))
                }

                if let rationale = stroke.gradingRationale {
                    Text(rationale)
                        .font(AppFont.body(size: 13))
                        .foregroundStyle(theme.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // Phase scores bar
                if let breakdown = stroke.phaseBreakdown {
                    HStack(spacing: Spacing.xxs) {
                        ForEach(breakdown.allPhases, id: \.0) { phase, detail in
                            phaseBar(phase: phase, detail: detail)
                        }
                    }
                }

                HStack {
                    Text("Tap for full breakdown →")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
            }
            .padding(Spacing.lg)
            .background(theme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
    }

    private func phaseBar(phase: SwingPhase, detail: PhaseDetail?) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(statusColor(detail?.status ?? .warning))
                .frame(height: 24)
                .overlay {
                    if let d = detail {
                        Text("\(d.score)")
                            .font(AppFont.mono(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            Text(phase.displayName)
                .font(AppFont.body(size: 8))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.prefix(1) {
        case "A": return theme.success
        case "B": return theme.accent
        case "C": return theme.warning
        default: return theme.error
        }
    }
}

// MARK: - Stroke Detail Sheet

struct DemoStrokeDetailView: View {
    let stroke: StrokeResult
    @Environment(\.dismiss) private var dismiss
    private let theme = DesignSystem.current

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(stroke.type.displayName)
                                    .font(AppFont.display(size: 24, weight: .bold))
                                    .foregroundStyle(theme.textPrimary)
                                if let rationale = stroke.gradingRationale {
                                    Text(rationale)
                                        .font(AppFont.body(size: 13))
                                        .foregroundStyle(theme.textSecondary)
                                        .lineSpacing(2)
                                }
                            }
                            Spacer()
                            Text(stroke.grade)
                                .font(AppFont.display(size: 36, weight: .bold))
                                .foregroundStyle(gradeColor(stroke.grade))
                        }

                        // Phase Breakdown
                        if let breakdown = stroke.phaseBreakdown {
                            phaseBreakdownSection(breakdown)
                        }

                        // Analysis Categories
                        if let categories = stroke.analysisCategories {
                            categoriesSection(categories)
                        }

                        // Drill Plan
                        if let plan = stroke.nextRepsPlan {
                            drillPlanCard(plan)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .navigationTitle("Stroke Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.accent)
                }
            }
        }
    }

    // MARK: - Phase Breakdown

    private func phaseBreakdownSection(_ breakdown: PhaseBreakdown) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Phase Breakdown")
                .font(AppFont.body(size: 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            ForEach(breakdown.allPhases, id: \.0) { phase, detail in
                if let detail {
                    phaseRow(phase: phase, detail: detail)
                }
            }
        }
    }

    private func phaseRow(phase: SwingPhase, detail: PhaseDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: phase.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(statusColor(detail.status))
                Text(phase.displayName)
                    .font(AppFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(detail.score)/10")
                    .font(AppFont.mono(size: 14, weight: .bold))
                    .foregroundStyle(statusColor(detail.status))
            }

            Text(detail.note)
                .font(AppFont.body(size: 13))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(2)

            if !detail.keyAngles.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(detail.keyAngles, id: \.self) { angle in
                        Text(angle)
                            .font(AppFont.mono(size: 10))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, 3)
                            .background(theme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            if let cue = detail.improveCue {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "lightbulb.min")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                    Text(cue)
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.accent)
                }
            }

            if let drill = detail.drill {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "figure.tennis")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accentSecondary)
                    Text(drill)
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            Divider().opacity(0.3)
        }
        .padding(Spacing.md)
        .background(theme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Categories

    private func categoriesSection(_ categories: [AnalysisCategory]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Analysis Categories")
                .font(AppFont.body(size: 17, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            ForEach(categories) { category in
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Circle()
                            .fill(statusColor(category.status))
                            .frame(width: 10, height: 10)
                        Text(category.name)
                            .font(AppFont.body(size: 15, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text(category.status.displayLabel)
                            .font(AppFont.mono(size: 11))
                            .foregroundStyle(statusColor(category.status))
                    }

                    ForEach(category.subchecks) { check in
                        HStack {
                            Image(systemName: check.status == .inZone ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(statusColor(check.status))
                            Text(check.checkpoint)
                                .font(AppFont.body(size: 13))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(check.result)
                                .font(AppFont.mono(size: 12))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.leading, Spacing.lg)
                    }
                }
                .padding(Spacing.md)
                .background(theme.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
        }
    }

    // MARK: - Drill Plan

    private func drillPlanCard(_ plan: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.accent)
                Text("This Week's Plan")
                    .font(AppFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
            }
            Text(plan)
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)
                .lineSpacing(3)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
    }

    // MARK: - Helpers

    private func statusColor(_ status: ZoneStatus) -> Color {
        switch status {
        case .inZone: return theme.success
        case .warning: return theme.warning
        case .outOfZone: return theme.error
        }
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade.prefix(1) {
        case "A": return theme.success
        case "B": return theme.accent
        case "C": return theme.warning
        default: return theme.error
        }
    }
}

#Preview {
    DemoAnalysisView()
}
