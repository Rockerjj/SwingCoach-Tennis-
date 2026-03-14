import SwiftUI
import SwiftData

@main
struct TennisIQApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var subscriptionService = SubscriptionService()
    private let analytics = AnalyticsService.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SessionModel.self,
            StrokeAnalysisModel.self,
            ProgressSnapshotModel.self,
            UserProfileModel.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .environmentObject(authService)
                .environmentObject(subscriptionService)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(.dark)
                .onAppear {
                    analytics.trackEvent(.appOpened)
                }
        }
    }
}
