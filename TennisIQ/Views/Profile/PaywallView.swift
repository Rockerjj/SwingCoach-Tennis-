import SwiftUI
import StoreKit

// MARK: - Paywall View
// Shown when a free user hits the 3-session analysis limit.
// Whoop-inspired dark design. Two tiers: monthly + annual (save badge).
// Handles purchase, restore, and error states.

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product? = nil
    @State private var isPurchasing = false
    @State private var errorMessage: String? = nil
    @State private var showError = false

    private let theme = DesignSystem.current

    private var monthlyProduct: Product? {
        subscriptionService.availableProducts.first {
            $0.id == AppConstants.Subscription.monthlyProductID
        }
    }

    private var annualProduct: Product? {
        subscriptionService.availableProducts.first {
            $0.id == AppConstants.Subscription.annualProductID
        }
    }

    // Monthly equivalent of annual price for savings badge
    private var annualMonthlyEquivalent: String? {
        guard let annual = annualProduct else { return nil }
        let monthly = annual.price / 12
        return monthly.formatted(.currency(code: annual.priceFormatStyle.currencyCode))
    }

    private var savingsPercent: Int? {
        guard let monthly = monthlyProduct, let annual = annualProduct else { return nil }
        let annualMonthly = annual.price / 12
        let savings = (monthly.price - annualMonthly) / monthly.price * 100
        return Int(savings.rounded())
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.10),
                    Color(red: 0.04, green: 0.08, blue: 0.15),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.08)))
                    }
                    .padding(.trailing, Spacing.md)
                    .padding(.top, Spacing.md)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {

                        // ── Hero ──
                        heroSection

                        // ── Feature list ──
                        featuresSection

                        // ── Product cards ──
                        if subscriptionService.isLoading {
                            ProgressView()
                                .tint(theme.accent)
                                .padding(.vertical, Spacing.xl)
                        } else if subscriptionService.availableProducts.isEmpty {
                            Text("Products unavailable. Check your connection.")
                                .font(AppFont.body(size: 14))
                                .foregroundStyle(theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding()
                        } else {
                            productsSection
                        }

                        // ── CTA button ──
                        ctaButton

                        // ── Restore + legal ──
                        legalFooter
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
        }
        .onAppear {
            // Pre-select annual if available
            selectedProduct = annualProduct ?? monthlyProduct
            if subscriptionService.availableProducts.isEmpty {
                Task { await subscriptionService.loadProducts() }
            }
        }
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(theme.accent.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "figure.tennis")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(theme.accent)
            }

            VStack(spacing: Spacing.xs) {
                Text("Unlock Tennique Pro")
                    .font(AppFont.display(size: 28))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("You've used your 3 free analyses.\nUpgrade to keep improving.")
                    .font(AppFont.body(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(paywallFeatures, id: \.title) { feature in
                HStack(spacing: Spacing.sm) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(AppFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(feature.subtitle)
                            .font(AppFont.body(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(.white.opacity(0.04))
                )
            }
        }
    }

    // MARK: - Products

    private var productsSection: some View {
        VStack(spacing: Spacing.sm) {
            // Annual (recommended)
            if let annual = annualProduct {
                ProductCard(
                    product: annual,
                    badge: savingsPercent.map { "Save \($0)%" },
                    subtitle: annualMonthlyEquivalent.map { "\($0)/mo billed annually" } ?? "",
                    isSelected: selectedProduct?.id == annual.id,
                    isRecommended: true
                ) {
                    selectedProduct = annual
                }
            }

            // Monthly
            if let monthly = monthlyProduct {
                ProductCard(
                    product: monthly,
                    badge: nil,
                    subtitle: "billed monthly",
                    isSelected: selectedProduct?.id == monthly.id,
                    isRecommended: false
                ) {
                    selectedProduct = monthly
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: purchase) {
            HStack(spacing: Spacing.sm) {
                if isPurchasing {
                    ProgressView()
                        .tint(.black)
                        .scaleEffect(0.85)
                } else {
                    Text(ctaLabel)
                        .font(AppFont.body(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(theme.accent)
            )
        }
        .disabled(isPurchasing || selectedProduct == nil)
        .opacity(selectedProduct == nil ? 0.5 : 1)
    }

    private var ctaLabel: String {
        guard let product = selectedProduct else { return "Select a plan" }
        let free = "Try Free" // if you add trial period, use product.subscription?.introductoryOffer
        _ = free
        return "Start for \(product.displayPrice)"
    }

    // MARK: - Legal Footer

    private var legalFooter: some View {
        VStack(spacing: Spacing.sm) {
            Button(action: restore) {
                Text("Restore Purchases")
                    .font(AppFont.body(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Text("Subscription auto-renews. Cancel anytime in Settings.\nPayment charged to Apple ID at confirmation.")
                .font(AppFont.body(size: 11))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
    }

    // MARK: - Actions

    private func purchase() {
        guard let product = selectedProduct else { return }
        isPurchasing = true
        Task {
            do {
                try await subscriptionService.purchase(product)
                await MainActor.run {
                    isPurchasing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func restore() {
        Task {
            await subscriptionService.restorePurchases()
            if subscriptionService.currentTier != .free {
                dismiss()
            }
        }
    }

    // MARK: - Feature Data

    private let paywallFeatures: [PaywallFeature] = [
        PaywallFeature(icon: "infinity", title: "Unlimited AI Analyses", subtitle: "Analyse every practice session, no limits"),
        PaywallFeature(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", subtitle: "See your brain change week over week"),
        PaywallFeature(icon: "list.bullet.clipboard", title: "Drill Plans", subtitle: "Personalised practice drills for every session"),
        PaywallFeature(icon: "square.and.arrow.up", title: "Shareable Score Cards", subtitle: "Export beautiful cards to TikTok & Instagram"),
        PaywallFeature(icon: "person.fill.checkmark", title: "Pro Comparison", subtitle: "See how your form compares to the pros"),
    ]
}

// MARK: - Product Card

private struct ProductCard: View {
    let product: Product
    let badge: String?
    let subtitle: String
    let isSelected: Bool
    let isRecommended: Bool
    let onSelect: () -> Void

    private let theme = DesignSystem.current

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                // Selection indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? theme.accent : .white.opacity(0.2), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.xs) {
                        Text(product.displayName)
                            .font(AppFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        if let badge {
                            Text(badge)
                                .font(AppFont.body(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(theme.accent)
                                )
                        }
                    }
                    Text(subtitle)
                        .font(AppFont.body(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Text(product.displayPrice)
                    .font(AppFont.display(size: 18))
                    .foregroundStyle(isSelected ? theme.accent : .white)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(isSelected ? theme.accentMuted : .white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.lg)
                            .strokeBorder(
                                isSelected ? theme.accent.opacity(0.5) : .white.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Supporting Types

private struct PaywallFeature {
    let icon: String
    let title: String
    let subtitle: String
}
