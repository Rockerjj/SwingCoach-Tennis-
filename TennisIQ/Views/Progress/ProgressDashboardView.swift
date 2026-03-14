import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Query(sort: \ProgressSnapshotModel.snapshotDate, order: .reverse)
    private var snapshots: [ProgressSnapshotModel]

    @Query(
        filter: #Predicate<SessionModel> { $0.status.rawValue == "ready" },
        sort: \SessionModel.recordedAt,
        order: .reverse
    )
    private var recentSessions: [SessionModel]

    let theme = DesignSystem.current

    private var latest: ProgressSnapshotModel? { snapshots.first }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                if snapshots.isEmpty {
                    emptyProgressState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            overallScoreCard
                            strokeBreakdownGrid
                            weeklyFocusCard
                            progressChart
                            sessionStreakCard
                        }
                        .padding(Spacing.md)
                        .padding(.bottom, Spacing.xxl)
                    }
                }
            }
            .navigationTitle("Progress")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Overall Score

    private var overallScoreCard: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .stroke(theme.surfaceSecondary, lineWidth: 10)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: (latest?.overallScore ?? 0) / 100)
                    .stroke(
                        theme.accent,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(latest?.overallScore ?? 0))")
                        .font(AppFont.display(size: 40))
                        .foregroundStyle(theme.textPrimary)

                    Text("Overall")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if let trend = latest?.trendingDirection {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: trend.icon)
                        .font(.system(size: 14, weight: .bold))

                    Text(trend.rawValue.capitalized)
                        .font(AppFont.body(size: 14, weight: .medium))
                }
                .foregroundStyle(trendColor(trend))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Stroke Breakdown Grid

    private var strokeBreakdownGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.sm),
            GridItem(.flexible(), spacing: Spacing.sm),
        ], spacing: Spacing.sm) {
            ForEach(StrokeType.allCases.filter { $0 != .unknown }, id: \.self) { stroke in
                strokeGauge(stroke)
            }
        }
    }

    private func strokeGauge(_ strokeType: StrokeType) -> some View {
        let score = latest?.score(for: strokeType) ?? 0

        return VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(theme.surfaceSecondary, lineWidth: 6)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        strokeTypeColor(strokeType),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(score))")
                    .font(AppFont.mono(size: 18, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
            }

            VStack(spacing: 2) {
                Text(strokeType.displayName)
                    .font(AppFont.body(size: 13, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Image(systemName: strokeType.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Weekly Focus

    private var weeklyFocusCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "target")
                .font(.system(size: 20))
                .foregroundStyle(theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("This Week's Focus")
                    .font(AppFont.body(size: 12))
                    .foregroundStyle(theme.textTertiary)

                Text(weeklyFocusText)
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.accentMuted)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .strokeBorder(theme.accent.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Progress Chart

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SCORE OVER TIME")
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(theme.textTertiary)

            if #available(iOS 16.0, *) {
                ProgressChartView(snapshots: Array(snapshots.prefix(30).reversed()))
                    .frame(height: 160)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    // MARK: - Session Streak

    private var sessionStreakCard: some View {
        let thisWeek = recentSessions.filter {
            Calendar.current.isDate($0.recordedAt, equalTo: Date(), toGranularity: .weekOfYear)
        }.count

        let thisMonth = recentSessions.filter {
            Calendar.current.isDate($0.recordedAt, equalTo: Date(), toGranularity: .month)
        }.count

        return HStack(spacing: Spacing.lg) {
            streakMetric(value: thisWeek, label: "This Week", icon: "flame.fill")
            Divider().frame(height: 40).background(theme.surfaceSecondary)
            streakMetric(value: thisMonth, label: "This Month", icon: "calendar")
            Divider().frame(height: 40).background(theme.surfaceSecondary)
            streakMetric(value: snapshots.count, label: "Total", icon: "figure.tennis")
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private func streakMetric(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(theme.accent)

            Text("\(value)")
                .font(AppFont.display(size: 22))
                .foregroundStyle(theme.textPrimary)

            Text(label)
                .font(AppFont.body(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyProgressState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No Progress Yet")
                    .font(AppFont.display(size: 22))
                    .foregroundStyle(theme.textPrimary)

                Text("Complete your first analysis\nto start tracking progress")
                    .font(AppFont.body(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - Helpers

    private var weeklyFocusText: String {
        guard let snap = latest else { return "Record a session to get started" }
        let scores: [(StrokeType, Double)] = [
            (.forehand, snap.forehandScore),
            (.backhand, snap.backhandScore),
            (.serve, snap.serveScore),
            (.volley, snap.volleyScore),
        ]
        let weakest = scores.min(by: { $0.1 < $1.1 })
        return "Work on your \(weakest?.0.displayName.lowercased() ?? "strokes")"
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving: return theme.success
        case .stable: return theme.accentSecondary
        case .declining: return theme.error
        }
    }

    private func strokeTypeColor(_ type: StrokeType) -> Color {
        switch type {
        case .forehand: return theme.accent
        case .backhand: return theme.accentSecondary
        case .serve: return theme.success
        case .volley: return theme.warning
        case .unknown: return theme.textTertiary
        }
    }
}

// MARK: - Simple Line Chart (iOS 16+)

@available(iOS 16.0, *)
struct ProgressChartView: View {
    let snapshots: [ProgressSnapshotModel]
    let theme = DesignSystem.current

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            let scores = snapshots.map(\.overallScore)
            let maxScore = max(scores.max() ?? 100, 100)
            let minScore = max((scores.min() ?? 0) - 10, 0)
            let range = max(maxScore - minScore, 1)

            ZStack {
                // Grid lines
                ForEach([0.25, 0.5, 0.75], id: \.self) { fraction in
                    Path { path in
                        let y = height * (1 - fraction)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(theme.surfaceSecondary, lineWidth: 0.5)
                }

                if snapshots.count >= 2 {
                    // Gradient fill
                    Path { path in
                        for (i, snap) in snapshots.enumerated() {
                            let x = width * CGFloat(i) / CGFloat(snapshots.count - 1)
                            let y = height * (1 - (snap.overallScore - minScore) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [theme.accent.opacity(0.2), theme.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        for (i, snap) in snapshots.enumerated() {
                            let x = width * CGFloat(i) / CGFloat(snapshots.count - 1)
                            let y = height * (1 - (snap.overallScore - minScore) / range)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Latest point dot
                    if let last = snapshots.last {
                        let x = width
                        let y = height * (1 - (last.overallScore - minScore) / range)
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}
