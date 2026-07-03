import Foundation
import CoreVideo

/// A pluggable pose estimation backend. All engines normalize their output to the
/// 17-joint COCO-style schema (`nose`, `left_shoulder`, `right_wrist`, ...) so that
/// StrokeDetector, OverlayRenderer, and the server payload stay engine-agnostic.
protocol PoseEngine: AnyObject {
    var identifier: String { get }

    /// Eagerly load any backing model so a missing/corrupt asset surfaces at
    /// session start instead of mid-frame. Default no-op for engines that have
    /// nothing to load (Vision).
    func warmUp() throws

    func extract(from pixelBuffer: CVPixelBuffer, frameIndex: Int, timestamp: Double) async throws -> FramePoseData?
}

extension PoseEngine {
    func warmUp() throws {}
}

enum PoseEngineKind: String, CaseIterable, Codable {
    case vision
    case mediapipe
    case movenet
    case visionHands = "vision+hands"
}
