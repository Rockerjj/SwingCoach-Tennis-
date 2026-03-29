import SwiftUI

// MARK: - Session Share Card
// A 9:16 portrait card (1080×1920pt logical) designed to be screenshotted
// and posted to TikTok/Instagram Reels/Stories. Shows overall session score,
// per-stroke grades, top coaching insight, and Tennique branding.
// Rendered via ImageRenderer for export, also shown as a preview sheet.

struct SessionShareCardView: View {
    let session: SessionModel

    // Computed once so the card is deterministic
    private var strokes: [StrokeAnalysisModel] {
        (session.strokeAnalyses ?? [])
            .filter { $0.strokeType != .unknown }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var overallGrade: String {
        // Derive from ProgressSnapshot if available; otherwise average stroke grades
        let letterGrades = strokes.map { $0.grade }
        let points = letterGrades.compactMap { gradeToPoints($0) }
        guard !points.isEmpty else { return "—" }
        let avg = points.reduce(0, +) / Double(points.count)
        return pointsToGrade(avg)
    }

    private var topInsight: String {
        // Find the lowest-scoring phase across all strokes
        var worst: (phase: String, stroke: String, cue: String)? = nil
        var lowestScore = Int.max

        for stroke in strokes {
            guard let pb = stroke.phaseBreakdown else { continue }
            for (phase, detail) in pb.allPhases {
                guard let detail else { continue }
                if detail.score < lowestScore, let cue = detail.improveCue, !cue.isEmpty {
                    lowestScore = detail.score
                    worst = (phase.displayName, stroke.strokeType.displayName, cue)
                }
            }
        }
        if let w = worst {
            return "Focus: \(w.stroke) \(w.phase) — \(w.cue)"
        }
        return session.tacticalNotes.first ?? "Keep up the great work!"
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.10),
                    Color(red: 0.06, green: 0.09, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle court grid lines
            CourtGridOverlay()
                .opacity(0.06)

            VStack(spacing: 0) {
                Spacer()

                // ── Brand Header ──
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.tennis")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.0))
                        Text("tennique")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("AI Tennis Coach")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .tracking(2)
                        .textCase(.uppercase)
                }
                .padding(.bottom, 36)

                // ── Overall Score Ring ──
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 14)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: gradeToFraction(overallGrade))
                        .stroke(
                            gradeAccentColor(overallGrade),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(overallGrade)
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(gradeAccentColor(overallGrade))
                        Text("Overall")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .tracking(1.5)
                            .textCase(.uppercase)
                    }
                }
                .padding(.bottom, 40)

                // ── Stroke Grid ──
                if !strokes.isEmpty {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(strokes.count, 4)),
                        spacing: 12
                    ) {
                        ForEach(strokes) { stroke in
                            StrokeGradeChip(stroke: stroke)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
                }

                // ── Top Insight ──
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                        Text("Coach's Note")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.2))
                            .tracking(1.5)
                            .textCase(.uppercase)
                    }
                    Text(topInsight)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                // ── Date + CTA ──
                VStack(spacing: 6) {
                    Text(session.recordedAt.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))

                    Text("Try Tennique free →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 1.0, blue: 0.0).opacity(0.8))
                        .tracking(0.5)
                }
                .padding(.bottom, 48)

                Spacer()
            }
        }
        .frame(width: 393, height: 852) // iPhone 14 Pro logical resolution — scales nicely to 1080×1920
    }

    // MARK: - Helpers

    private func gradeToPoints(_ grade: String) -> Double? {
        switch grade.prefix(2) {
        case "A+": return 4.3
        case "A": return 4.0
        case "A-": return 3.7
        case "B+": return 3.3
        case "B": return 3.0
        case "B-": return 2.7
        case "C+": return 2.3
        case "C": return 2.0
        case "C-": return 1.7
        case "D": return 1.0
        default: return nil
        }
    }

    private func pointsToGrade(_ pts: Double) -> String {
        switch pts {
        case 4.15...: return "A+"
        case 3.85...: return "A"
        case 3.5...: return "A-"
        case 3.15...: return "B+"
        case 2.85...: return "B"
        case 2.5...: return "B-"
        case 2.15...: return "C+"
        case 1.85...: return "C"
        case 1.5...: return "C-"
        default: return "D"
        }
    }

    private func gradeToFraction(_ grade: String) -> CGFloat {
        let pts = gradeToPoints(grade) ?? 2.0
        return CGFloat(pts / 4.3)
    }

    private func gradeAccentColor(_ grade: String) -> Color {
        switch grade.prefix(1) {
        case "A": return Color(red: 0.2, green: 0.9, blue: 0.45)
        case "B": return Color(red: 0.78, green: 1.0, blue: 0.0)
        case "C": return Color(red: 1.0, green: 0.75, blue: 0.0)
        default: return Color(red: 1.0, green: 0.36, blue: 0.36)
        }
    }
}

// MARK: - Stroke Grade Chip

private struct StrokeGradeChip: View {
    let stroke: StrokeAnalysisModel

    private var chipColor: Color {
        switch stroke.grade.prefix(1) {
        case "A": return Color(red: 0.2, green: 0.9, blue: 0.45)
        case "B": return Color(red: 0.78, green: 1.0, blue: 0.0)
        case "C": return Color(red: 1.0, green: 0.75, blue: 0.0)
        default: return Color(red: 1.0, green: 0.36, blue: 0.36)
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: stroke.strokeType.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(chipColor)

            Text(stroke.grade)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(chipColor)

            Text(stroke.strokeType.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(chipColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(chipColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Court Grid Overlay (decorative)

private struct CourtGridOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            Path { path in
                // Vertical lines
                for i in 0...6 {
                    let x = w * CGFloat(i) / 6
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: h))
                }
                // Horizontal lines
                for i in 0...10 {
                    let y = h * CGFloat(i) / 10
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: w, y: y))
                }
                // Court baseline arc suggestion
                path.addEllipse(in: CGRect(x: w * 0.1, y: h * 0.3, width: w * 0.8, height: h * 0.5))
            }
            .stroke(.white, lineWidth: 0.5)
        }
    }
}

// MARK: - Share Sheet Presenter

struct SessionShareSheet: View {
    let session: SessionModel
    @State private var renderedImage: UIImage? = nil
    @State private var isRendering = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Preview
                if let img = renderedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                } else {
                    SessionShareCardView(session: session)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        .scaleEffect(0.38)
                        .frame(height: 320)
                }

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: shareImage) {
                        HStack(spacing: 8) {
                            if isRendering {
                                ProgressView()
                                    .tint(.black)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(isRendering ? "Preparing..." : "Share")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(red: 0.78, green: 1.0, blue: 0.0))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isRendering)
                    .padding(.horizontal, 24)

                    Button("Close") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 32)
            }
            .padding(.top, 24)
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = renderedImage {
                ShareSheetRepresentable(items: [
                    img,
                    "AI analyzed my tennis today! 🎾 Try Tennique free ↓"
                ])
                .ignoresSafeArea()
            }
        }
    }

    @MainActor
    private func shareImage() {
        isRendering = true
        Task {
            let card = SessionShareCardView(session: session)
            let renderer = ImageRenderer(content: card)
            renderer.scale = UIScreen.main.scale * 2 // 2x → ~1080pt wide
            renderedImage = renderer.uiImage
            isRendering = false
            showShareSheet = true
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheetRepresentable: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = [.addToReadingList, .assignToContact, .openInIBooks]
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
