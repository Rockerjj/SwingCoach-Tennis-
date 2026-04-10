import SwiftUI

struct LaunchView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var taglineOpacity: Double = 0

    private let brandDarkGreen = Color(red: 15/255, green: 26/255, blue: 18/255)
    private let brandCream = Color(red: 238/255, green: 242/255, blue: 228/255)

    var body: some View {
        ZStack {
            brandDarkGreen
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image("TenniqueLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("AI-Powered Coaching")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(brandCream.opacity(0.5))
                    .tracking(2)
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
}
