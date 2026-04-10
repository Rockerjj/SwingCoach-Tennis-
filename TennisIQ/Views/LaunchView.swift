import SwiftUI

struct LaunchView: View {
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0

    private let brandGreen = Color(red: 84/255, green: 113/255, blue: 83/255)
    private let brandCream = Color(red: 238/255, green: 242/255, blue: 228/255)
    private let brandDarkGreen = Color(red: 15/255, green: 26/255, blue: 18/255)

    var body: some View {
        ZStack {
            brandDarkGreen
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(brandGreen.opacity(0.15))
                        .frame(width: 140, height: 140)

                    Circle()
                        .fill(brandGreen.opacity(0.08))
                        .frame(width: 110, height: 110)

                    tenniqueLogo
                        .frame(width: 70, height: 70)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 6) {
                    Text("Tennique")
                        .font(.system(size: 36, weight: .light, design: .default))
                        .foregroundStyle(brandCream)
                        .tracking(1)

                    Text("AI-Powered Coaching")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(brandCream.opacity(0.5))
                        .tracking(2)
                }
                .opacity(taglineOpacity)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                taglineOpacity = 1.0
            }
        }
    }

    private var tenniqueLogo: some View {
        ZStack {
            Circle()
                .stroke(brandCream, lineWidth: 3)
                .frame(width: 50, height: 50)

            Path { path in
                path.move(to: CGPoint(x: 30, y: 38))
                path.addQuadCurve(
                    to: CGPoint(x: 18, y: 15),
                    control: CGPoint(x: 10, y: 28)
                )
                path.addQuadCurve(
                    to: CGPoint(x: 30, y: 22),
                    control: CGPoint(x: 24, y: 10)
                )
            }
            .stroke(brandCream, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 50, height: 50)
        }
    }
}
