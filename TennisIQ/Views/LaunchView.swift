import SwiftUI

struct LaunchView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.85
    @State private var taglineOpacity: Double = 0

    private let brandBackground = Color(red: 10/255, green: 18/255, blue: 12/255)
    private let brandCream = Color(red: 238/255, green: 242/255, blue: 228/255)

    var body: some View {
        ZStack {
            brandBackground
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image("TenniqueLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 220)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Text("AI-Powered Coaching")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(brandCream.opacity(0.45))
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
