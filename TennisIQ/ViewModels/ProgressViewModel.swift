import Foundation
import SwiftUI
import SwiftData

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncDate: Date?

    private let apiService = AnalysisAPIService()

    func sync(context: ModelContext) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let authToken = AuthService().authToken
            let data = try await apiService.fetchProgress(authToken: authToken)

            upsertLatestSnapshot(from: data, context: context)
            upsertHistory(from: data.history, context: context)

            try? context.save()
            lastSyncDate = Date()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func upsertLatestSnapshot(from data: ProgressData, context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())

        let descriptor = FetchDescriptor<ProgressSnapshotModel>(
            predicate: #Predicate { $0.snapshotDate >= today }
        )
        let existing = (try? context.fetch(descriptor))?.first

        let snapshot = existing ?? ProgressSnapshotModel()
        snapshot.snapshotDate = today
        snapshot.overallScore = data.overallScore
        snapshot.forehandScore = data.forehandScore
        snapshot.backhandScore = data.backhandScore
        snapshot.serveScore = data.serveScore
        snapshot.volleyScore = data.volleyScore
        snapshot.sessionsCount = data.sessionsThisMonth
        snapshot.trendingDirection = TrendDirection(rawValue: data.trend) ?? .stable

        if existing == nil {
            context.insert(snapshot)
        }
    }

    private func upsertHistory(from history: [ProgressPoint], context: ModelContext) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for point in history {
            guard let date = dateFormatter.date(from: point.date) else { continue }
            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

            let descriptor = FetchDescriptor<ProgressSnapshotModel>(
                predicate: #Predicate { $0.snapshotDate >= startOfDay && $0.snapshotDate < endOfDay }
            )

            if let existing = try? context.fetch(descriptor), !existing.isEmpty {
                continue
            }

            let snapshot = ProgressSnapshotModel(
                snapshotDate: startOfDay,
                overallScore: point.score
            )
            context.insert(snapshot)
        }
    }
}
