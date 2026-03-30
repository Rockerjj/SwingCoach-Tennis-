import SwiftUI

// MARK: - Stroke Grade History Card
// Shows grade progression per stroke type across sessions

struct StrokeGradeHistoryCard: View {
    let sessions: [SessionModel]
    let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("GRADE HISTORY")
                .font(AppFont.body(size: 11, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
                .tracking(0.5)

            // One sparkline row per stroke type
            ForEach(StrokeType.allCases.filter { $0 != .unknown }, id: \.self) { strokeType in
                let grades = gradesForStroke(strokeType)
                if !grades.isEmpty {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: strokeType.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(colorForStroke(strokeType))
                            .frame(width: 20)

                        Text(strokeType.displayName)
                            .font(AppFont.body(size: 12, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                            .frame(width: 80, alignment: .leading)

                        // Sparkline of grades
                        GradeSparkline(grades: grades, color: colorForStroke(strokeType))
                            .frame(height: 24)

                        // Latest grade
                        if let latest = grades.last {
                            Text(latest)
                                .font(AppFont.mono(size: 13, weight: .bold))
                                .foregroundStyle(colorForGrade(latest))
                                .frame(width: 28)
                        }
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private func gradesForStroke(_ type: StrokeType) -> [String] {
        sessions.flatMap { session in
            session.strokeAnalyses
                .filter { $0.strokeType == type }
                .map { $0.grade }
        }
    }

    private func colorForStroke(_ type: StrokeType) -> Color {
        switch type {
        case .forehand: return theme.accent
        case .backhand: return theme.accentSecondary
        case .serve: return theme.success
        case .volley: return theme.warning
        case .unknown: return theme.textTertiary
        }
    }

    private func colorForGrade(_ grade: String) -> Color {
        let g = grade.uppercased()
        if g.hasPrefix("A") { return theme.success }
        if g.hasPrefix("B") { return theme.accent }
        if g.hasPrefix("C") { return theme.warning }
        return theme.error
    }
}

// MARK: - Grade Sparkline
// Mini line chart showing grade trend (A+ = 100, F = 0)

struct GradeSparkline: View {
    let grades: [String]
    let color: Color

    private func numericGrade(_ g: String) -> Double {
        let clean = g.uppercased().trimmingCharacters(in: .whitespaces)
        switch clean {
        case "A+": return 97; case "A": return 93; case "A-": return 90
        case "B+": return 87; case "B": return 83; case "B-": return 80
        case "C+": return 77; case "C": return 73; case "C-": return 70
        case "D+": return 67; case "D": return 63; case "D-": return 60
        default: return 50
        }
    }

    var body: some View {
        GeometryReader { geo in
            let values = grades.map { numericGrade($0) }
            let minV = max((values.min() ?? 50) - 10, 0)
            let maxV = min((values.max() ?? 100) + 10, 100)
            let range = max(maxV - minV, 1)

            if values.count >= 2 {
                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = geo.size.height * (1 - (v - minV) / range)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else {
                // Single dot
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }
}

// MARK: - Session Progress Row
// Compact row showing one analyzed session with its stroke grades

struct SessionProgressRow: View {
    let session: SessionModel
    let theme = DesignSystem.current

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Header: date + overall grade
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.recordedAt, style: .date)
                        .font(AppFont.body(size: 14, weight: .medium))
                        .foregroundStyle(theme.textPrimary)

                    Text(formatDuration(session.durationSeconds))
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if let grade = session.overallGrade {
                    GradeBadge(grade: grade)
                }
            }

            // Stroke chips
            if !session.strokeAnalyses.isEmpty {
                HStack(spacing: Spacing.xs) {
                    ForEach(session.strokeAnalyses.sorted(by: { $0.timestamp < $1.timestamp })) { stroke in
                        HStack(spacing: 3) {
                            Image(systemName: stroke.strokeType.icon)
                                .font(.system(size: 10))
                            Text(stroke.grade)
                                .font(AppFont.mono(size: 11, weight: .bold))
                        }
                        .foregroundStyle(theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(theme.surfaceSecondary)
                        )
                    }
                }
            }

            // Top priority
            if let priority = session.topPriority, !priority.isEmpty {
                Text("Focus: \(priority)")
                    .font(AppFont.body(size: 12))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
