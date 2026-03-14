import SwiftUI
import SwiftData

struct SessionsListView: View {
    @Query(sort: \SessionModel.recordedAt, order: .reverse) private var sessions: [SessionModel]
    @Environment(\.modelContext) private var modelContext
    @State private var isRetryingFailed = false
    @State private var retryProgress = 0
    @State private var retryTotal = 0
    let theme = DesignSystem.current

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .navigationTitle("Sessions")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if failedSessionsCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isRetryingFailed ? "Retrying..." : "Retry Failed (\(failedSessionsCount))") {
                        Task { await retryFailedSessions() }
                    }
                    .disabled(isRetryingFailed)
                }
            }
        }
        .overlay(alignment: .top) {
            if isRetryingFailed {
                VStack(spacing: Spacing.xs) {
                    ProgressView(value: retryTotal == 0 ? 0 : Double(retryProgress), total: Double(max(retryTotal, 1)))
                        .tint(theme.accent)
                    Text("Retrying failed sessions (\(retryProgress)/\(retryTotal))")
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(theme.surfacePrimary)
                )
                .padding(.top, Spacing.sm)
            }
        }
    }

    private var failedSessionsCount: Int {
        sessions.filter { $0.status == .failed }.count
    }

    @MainActor
    private func retryFailedSessions() async {
        let failed = sessions.filter { $0.status == .failed }
        guard !failed.isEmpty else { return }

        isRetryingFailed = true
        retryProgress = 0
        retryTotal = failed.count

        for session in failed {
            session.status = .processing
            try? modelContext.save()

            let vm = AnalysisViewModel(session: session)
            await vm.triggerAnalysis(context: modelContext)
            retryProgress += 1
        }

        isRetryingFailed = false
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(sessions) { session in
                    NavigationLink(destination: AnalysisResultsView(session: session)) {
                        SessionRowView(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "video.slash")
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(theme.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No Sessions Yet")
                    .font(AppFont.display(size: 22))
                    .foregroundStyle(theme.textPrimary)

                Text("Record your first tennis session\nto get AI coaching feedback")
                    .font(AppFont.body(size: 15))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - Session Row

struct SessionRowView: View {
    let session: SessionModel
    let theme = DesignSystem.current

    var body: some View {
        HStack(spacing: Spacing.md) {
            thumbnailView

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(session.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.body(size: 15, weight: .medium))
                    .foregroundStyle(theme.textPrimary)

                Text(formattedDuration)
                    .font(AppFont.mono(size: 13))
                    .foregroundStyle(theme.textSecondary)

                statusBadge
            }

            Spacer()

            if let grade = session.overallGrade {
                gradeView(grade)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(theme.surfacePrimary)
        )
    }

    private var thumbnailView: some View {
        RoundedRectangle(cornerRadius: Radius.sm)
            .fill(theme.surfaceSecondary)
            .frame(width: 56, height: 56)
            .overlay {
                if let data = session.thumbnailData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
                } else {
                    Image(systemName: "figure.tennis")
                        .foregroundStyle(theme.textTertiary)
                }
            }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText)
                .font(AppFont.body(size: 12))
                .foregroundStyle(statusColor)
        }
    }

    private func gradeView(_ grade: String) -> some View {
        Text(grade)
            .font(AppFont.display(size: 20))
            .foregroundStyle(theme.accent)
            .frame(width: 44, alignment: .center)
    }

    private var statusColor: Color {
        switch session.status {
        case .ready: return theme.success
        case .analyzing, .processing: return theme.warning
        case .failed: return theme.error
        case .recording: return theme.accent
        }
    }

    private var statusText: String {
        switch session.status {
        case .recording: return "Recording"
        case .processing: return "Processing..."
        case .analyzing: return "Analyzing..."
        case .ready: return "Ready"
        case .failed: return "Failed"
        }
    }

    private var formattedDuration: String {
        let minutes = session.durationSeconds / 60
        let seconds = session.durationSeconds % 60
        return "\(minutes)m \(seconds)s"
    }
}
