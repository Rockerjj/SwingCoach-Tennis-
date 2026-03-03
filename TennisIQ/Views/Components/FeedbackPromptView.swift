import SwiftUI

struct FeedbackPromptView: View {
    @Binding var isPresented: Bool
    @State private var selectedRating: Int = 0
    @State private var feedbackText = ""
    @State private var isSubmitting = false
    @State private var didSubmit = false

    private let theme = DesignSystem.current
    let onSubmit: (Int, String) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: Spacing.lg) {
                header
                ratingStars
                feedbackField
                actionButtons
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(theme.surfacePrimary)
            )
            .padding(.horizontal, Spacing.lg)
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(theme.accent)

            Text(didSubmit ? "Thank You!" : "How was your analysis?")
                .font(AppFont.display(size: 20))
                .foregroundStyle(theme.textPrimary)

            Text(didSubmit
                 ? "Your feedback helps us improve."
                 : "Your feedback shapes how we build this app.")
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var ratingStars: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Button(action: { withAnimation(.easeInOut(duration: 0.15)) { selectedRating = star } }) {
                    Image(systemName: star <= selectedRating ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(star <= selectedRating ? theme.accent : theme.textTertiary)
                }
            }
        }
        .opacity(didSubmit ? 0.5 : 1)
        .disabled(didSubmit)
    }

    private var feedbackField: some View {
        Group {
            if !didSubmit {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("What would make this better?")
                        .font(AppFont.body(size: 12, weight: .medium))
                        .foregroundStyle(theme.textTertiary)

                    TextField("Optional feedback...", text: $feedbackText, axis: .vertical)
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(3...5)
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm)
                                .fill(theme.surfaceSecondary)
                        )
                }
            }
        }
    }

    private var actionButtons: some View {
        Group {
            if didSubmit {
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(AppFont.body(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(theme.accent)
                        )
                }
            } else {
                VStack(spacing: Spacing.xs) {
                    Button(action: submit) {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .tint(theme.textOnAccent)
                            } else {
                                Text("Submit Feedback")
                                    .font(AppFont.body(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(selectedRating > 0 ? theme.accent : theme.textTertiary)
                        )
                    }
                    .disabled(selectedRating == 0 || isSubmitting)

                    Button("Not Now") { dismiss() }
                        .font(AppFont.body(size: 14))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private func submit() {
        guard selectedRating > 0 else { return }
        isSubmitting = true

        AnalyticsService.shared.trackEvent(.feedbackSubmitted(rating: selectedRating))
        AnalyticsService.shared.markFeedbackGiven()
        onSubmit(selectedRating, feedbackText)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSubmitting = false
            withAnimation { didSubmit = true }
        }
    }

    private func dismiss() {
        if !didSubmit {
            AnalyticsService.shared.trackEvent(.feedbackPromptDismissed)
        }
        isPresented = false
    }
}
