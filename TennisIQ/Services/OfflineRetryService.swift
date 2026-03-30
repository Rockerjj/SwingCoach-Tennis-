import Foundation
import SwiftData
import Combine

/// Watches for network restoration and automatically retries pending analyses.
/// Sessions with `.processing` status are retried when connectivity returns.
@MainActor
final class OfflineRetryService: ObservableObject {
    static let shared = OfflineRetryService()

    @Published var isRetrying = false
    @Published var retryCount = 0

    private var cancellable: AnyCancellable?
    private var wasOffline = false
    private var modelContainer: ModelContainer?

    private init() {}

    /// Call once at app launch with the shared ModelContainer
    func configure(container: ModelContainer) {
        self.modelContainer = container
        startWatching()
    }

    private func startWatching() {
        cancellable = NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                if !connected {
                    self.wasOffline = true
                } else if self.wasOffline {
                    self.wasOffline = false
                    // Network just came back — retry pending sessions
                    Task { @MainActor in
                        await self.retryPendingSessions()
                    }
                }
            }
    }

    /// Retry all sessions stuck in `.processing` status (offline failures)
    func retryPendingSessions() async {
        guard !isRetrying, let container = modelContainer else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SessionModel>()

        guard let allSessions = try? context.fetch(descriptor) else { return }
        let pending = allSessions.filter { $0.status == .processing }

        guard !pending.isEmpty else { return }
        guard NetworkMonitor.shared.isConnected else { return }

        isRetrying = true
        retryCount = pending.count

        for session in pending {
            guard NetworkMonitor.shared.isConnected else { break }

            let vm = AnalysisViewModel(session: session)
            await vm.triggerAnalysis(context: context)

            // Small delay between retries to avoid hammering the API
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        isRetrying = false
        retryCount = 0
    }
}
