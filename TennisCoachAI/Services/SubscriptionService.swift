import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    @Published var currentTier: SubscriptionTier = .free
    @Published var freeAnalysesUsed: Int = 0
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false

    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = [
                AppConstants.Subscription.monthlyProductID,
                AppConstants.Subscription.annualProductID,
            ]
            availableProducts = try await Product.products(for: Set(productIDs))
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()

        case .pending:
            break
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // MARK: - Check Entitlement

    func recordAnalysisUsed() {
        if currentTier == .free {
            freeAnalysesUsed += 1
            UserDefaults.standard.set(freeAnalysesUsed, forKey: "freeAnalysesUsed")
        }
    }

    var canAnalyze: Bool {
        currentTier != .free || freeAnalysesUsed < AppConstants.Analysis.freeSessionsAllowed
    }

    // MARK: - Private

    private func updateSubscriptionStatus() async {
        freeAnalysesUsed = UserDefaults.standard.integer(forKey: "freeAnalysesUsed")

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.productID == AppConstants.Subscription.annualProductID {
                currentTier = .annual
                return
            } else if transaction.productID == AppConstants.Subscription.monthlyProductID {
                currentTier = .monthly
                return
            }
        }

        currentTier = .free
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard let _ = try? self.checkVerified(result) else { continue }
                await self.updateSubscriptionStatus()
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
