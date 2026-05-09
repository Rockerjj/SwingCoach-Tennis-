import SwiftUI
import AVFoundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers

/// Developer-only pose-engine comparison lab. Loads a video, runs one or more
/// `PoseEngine`s over its frames, then lets you scrub frame-by-frame with each
/// engine's skeleton overlaid in a different color so jitter and tracking
/// quality can be eyeballed side-by-side.
///
/// Phase 1 ships with Vision only. MediaPipe / MoveNet / Hands engines will be
/// added once their dependencies land.
struct PoseCompareView: View {
    @StateObject private var model = PoseCompareViewModel()
    @State private var pickerPresented = false
    @State private var scrubValue: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                framePanel
                    .frame(maxWidth: .infinity)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .background(Color.black)
                    .cornerRadius(12)

                if model.duration > 0 {
                    scrubBar
                }

                engineStatusList

                Spacer()
            }
            .padding()
            .navigationTitle("Pose Compare")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Load Video") { pickerPresented = true }
                }
            }
            .sheet(isPresented: $pickerPresented) {
                VideoPickerSheet(onPick: { url in
                    pickerPresented = false
                    scrubValue = 0
                    Task { await model.load(videoURL: url) }
                })
            }
        }
    }

    @ViewBuilder private var framePanel: some View {
        if let baseImage = model.frameImage(at: scrubValue) {
            ZStack {
                Image(uiImage: baseImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                SkeletonOverlayLayer(model: model, time: scrubValue)
                    .allowsHitTesting(false)
            }
        } else if model.isExtracting {
            VStack(spacing: 12) {
                ProgressView(value: model.extractionProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                Text("Extracting pose…")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "figure.tennis")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Load a video to compare pose engines")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var scrubBar: some View {
        VStack(spacing: 4) {
            Slider(value: $scrubValue, in: 0...max(0.01, model.duration))
            HStack {
                Text(String(format: "%.2fs", scrubValue))
                Spacer()
                Text(String(format: "%.2fs", model.duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var engineStatusList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.engineResults) { result in
                HStack {
                    Circle()
                        .fill(Color(result.color))
                        .frame(width: 10, height: 10)
                    Text(result.identifier)
                        .font(.system(.body, design: .monospaced))
                    Spacer()
                    Text("\(result.frameCount) frames · avg conf \(String(format: "%.2f", result.avgConfidence))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - ViewModel

@MainActor
final class PoseCompareViewModel: ObservableObject {
    @Published var isExtracting = false
    @Published var extractionProgress: Double = 0
    @Published private(set) var engineResults: [EngineResult] = []
    @Published private(set) var duration: Double = 0

    private var videoURL: URL?
    private var frameGenerator: AVAssetImageGenerator?

    struct EngineResult: Identifiable {
        let id = UUID()
        let identifier: String
        let color: UIColor
        let frames: [FramePoseData]
        var frameCount: Int { frames.count }
        var avgConfidence: Double {
            guard !frames.isEmpty else { return 0 }
            let total = frames.reduce(0) { $0 + Double($1.confidence) }
            return total / Double(frames.count)
        }
    }

    func load(videoURL: URL) async {
        isExtracting = true
        extractionProgress = 0
        defer { isExtracting = false }

        self.videoURL = videoURL

        let asset = AVURLAsset(url: videoURL)
        if let loadedDuration = try? await asset.load(.duration) {
            self.duration = loadedDuration.seconds
        }

        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)
        self.frameGenerator = gen

        let engines: [(PoseEngine, UIColor)] = [
            (VisionPoseEngine(), .white),
            (MediaPipePoseEngine(), .systemGreen),
        ]

        var results: [EngineResult] = []
        for (engine, color) in engines {
            let service = PoseEstimationService(engine: engine)
            do {
                let extracted = try await service.extractPoses(from: videoURL)
                results.append(EngineResult(
                    identifier: engine.identifier,
                    color: color,
                    frames: extracted.frames
                ))
            } catch {
                print("[PoseCompare] \(engine.identifier) failed: \(error)")
            }
        }

        self.engineResults = results
    }

    func frameImage(at time: Double) -> UIImage? {
        guard let gen = frameGenerator else { return nil }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        do {
            let cgImage = try gen.copyCGImage(at: cmTime, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    func nearestFrame(forResult result: EngineResult, atTime time: Double) -> FramePoseData? {
        result.frames.min(by: { abs($0.timestamp - time) < abs($1.timestamp - time) })
    }
}

// MARK: - Overlay Layer

private struct SkeletonOverlayLayer: View {
    @ObservedObject var model: PoseCompareViewModel
    let time: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(model.engineResults) { result in
                    if let frame = model.nearestFrame(forResult: result, atTime: time) {
                        SkeletonShape(pose: frame, color: result.color)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct SkeletonShape: View {
    let pose: FramePoseData
    let color: UIColor

    private static let bones: [(String, String)] = [
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_elbow"),
        ("left_elbow", "left_wrist"),
        ("right_shoulder", "right_elbow"),
        ("right_elbow", "right_wrist"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle"),
    ]

    var body: some View {
        Canvas { context, size in
            let jointMap = Dictionary(uniqueKeysWithValues: pose.joints.map { ($0.name, $0) })
            let swiftColor = Color(color)

            for (a, b) in Self.bones {
                guard let ja = jointMap[a], let jb = jointMap[b] else { continue }
                let pa = CGPoint(x: ja.x * size.width, y: (1 - ja.y) * size.height)
                let pb = CGPoint(x: jb.x * size.width, y: (1 - jb.y) * size.height)
                var path = Path()
                path.move(to: pa)
                path.addLine(to: pb)
                context.stroke(path, with: .color(swiftColor), lineWidth: 2)
            }

            for joint in pose.joints {
                let p = CGPoint(x: joint.x * size.width, y: (1 - joint.y) * size.height)
                let dot = Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6))
                context.fill(dot, with: .color(swiftColor))
            }
        }
    }
}

// MARK: - Video Picker (PHPicker wrapper)

private struct VideoPickerSheet: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                picker.dismiss(animated: true)
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, _ in
                guard let url = url else { return }
                let copy = FileManager.default.temporaryDirectory
                    .appendingPathComponent("pose_compare_\(UUID().uuidString).mov")
                try? FileManager.default.copyItem(at: url, to: copy)
                DispatchQueue.main.async {
                    self?.onPick(copy)
                    picker.dismiss(animated: true)
                }
            }
        }
    }
}

#if DEBUG
#Preview { PoseCompareView() }
#endif
