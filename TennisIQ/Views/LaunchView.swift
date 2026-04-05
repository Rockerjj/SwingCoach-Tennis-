import SwiftUI

struct LaunchView: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.8

    private let theme = DesignSystem.current

    var body: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Spacer()

                ZStack {
                    // Pulsing ring behind the icon
                    Circle()
                        .stroke(theme.accent.opacity(0.15), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .rotationEffect(.degrees(ringRotation))

                    Circle()
                        .fill(theme.accent.opacity(0.06))
                        .frame(width: 120, height: 120)

                    Image(systemName: "figure.tennis")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(theme.accent)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: Spacing.xs) {
                    Text("TennisIQ")
                        .font(AppFont.display(size: 34))
                        .foregroundStyle(theme.textPrimary)

                    Text("AI-Powered Coaching")
                        .font(AppFont.body(size: 15))
                        .foregroundStyle(theme.textTertiary)
                        .tracking(1.5)
                }
                .opacity(taglineOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                logoScale = 1.0
                logoOpacity = 1.0
                ringScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                taglineOpacity = 1.0
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }
}
