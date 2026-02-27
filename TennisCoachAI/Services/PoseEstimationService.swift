import Foundation
import Vision
import AVFoundation
import UIKit
import Combine

/// Processes video frames through Apple Vision to extract body pose data
final class PoseEstimationService: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var error: PoseError?

    private let processingQueue = DispatchQueue(label: "com.tenniscoachai.pose", qos: .userInitiated)

    enum PoseError: LocalizedError {
        case videoLoadFailed
        case noPersonDetected
        case processingFailed(String)

        var errorDescription: String? {
            switch self {
            case .videoLoadFailed: return "Failed to load video for analysis."
            case .noPersonDetected: return "No person detected in the video. Make sure you're visible in frame."
            case .processingFailed(let msg): return "Processing failed: \(msg)"
            }
        }
    }

    struct ExtractionResult {
        let frames: [FramePoseData]
        let keyFrames: [(timestamp: Double, image: UIImage)]
        let duration: Double
        let detectedStrokes: [DetectedStroke]
    }

    // MARK: - Main Extraction Pipeline

    func extractPoses(from videoURL: URL) async throws -> ExtractionResult {
        await MainActor.run {
            isProcessing = true
            progress = 0
        }

        defer {
            Task { @MainActor in
                self.isProcessing = false
            }
        }

        let asset = AVURLAsset(url: videoURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw PoseError.videoLoadFailed
        }

        let duration = try await asset.load(.duration).seconds
        let nominalFPS = try await videoTrack.load(.nominalFrameRate)
        let totalFrames = Int(duration * Double(nominalFPS))

        // Sample every Nth frame to achieve target processing FPS
        let sampleInterval = max(1, Int(nominalFPS) / AppConstants.Camera.processingFPS)

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)
        reader.startReading()

        var allFrames: [FramePoseData] = []
        var keyFrames: [(timestamp: Double, image: UIImage)] = []
        var frameIndex = 0
        var previousWristVelocity: Double = 0
        var lastStrokeTimestamp: Double = -10
        var recentVelocities: [Double] = []

        while reader.status == .reading, let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            frameIndex += 1

            if frameIndex % sampleInterval != 0 { continue }
            let currentFrameIndex = frameIndex

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

            if let poseData = try await detectPose(in: pixelBuffer, frameIndex: currentFrameIndex, timestamp: timestamp) {
                allFrames.append(poseData)

                let wristVelocity = calculateWristVelocity(current: poseData, previous: allFrames.dropLast().last)
                recentVelocities.append(wristVelocity)
                if recentVelocities.count > 10 { recentVelocities.removeFirst() }

                let avgVelocity = recentVelocities.reduce(0, +) / Double(recentVelocities.count)
                let isHighVelocity = wristVelocity > 0.03 && wristVelocity > avgVelocity * 1.8
                let isDeceleration = previousWristVelocity > 0.03 && wristVelocity < previousWristVelocity * 0.6
                let isStrokeApex = (isHighVelocity || isDeceleration) && (timestamp - lastStrokeTimestamp) > minTimeBetweenStrokes
                previousWristVelocity = wristVelocity

                if isStrokeApex && keyFrames.count < AppConstants.Analysis.maxKeyFrames {
                    let image = imageFromPixelBuffer(pixelBuffer)
                    keyFrames.append((timestamp: timestamp, image: image))
                    lastStrokeTimestamp = timestamp
                }
            }

            await MainActor.run {
                self.progress = Double(currentFrameIndex) / Double(totalFrames)
            }
        }

        guard !allFrames.isEmpty else {
            throw PoseError.noPersonDetected
        }

        let detector = StrokeDetector()
        let detectedStrokes = detector.detectStrokes(frames: allFrames)

        if !detectedStrokes.isEmpty {
            var strokeKeyFrames: [(timestamp: Double, image: UIImage)] = []
            for stroke in detectedStrokes {
                let contactTime = stroke.contactTimestamp
                if let existingKF = keyFrames.first(where: { abs($0.timestamp - contactTime) < 0.2 }) {
                    strokeKeyFrames.append(existingKF)
                }
            }
            if !strokeKeyFrames.isEmpty {
                keyFrames = strokeKeyFrames + keyFrames.filter { kf in
                    !strokeKeyFrames.contains(where: { abs($0.timestamp - kf.timestamp) < 0.5 })
                }
            }
        }

        if keyFrames.count < 5 {
            keyFrames = try await extractEvenlySpacedKeyFrames(from: videoURL, count: 10, duration: duration)
        }

        return ExtractionResult(frames: allFrames, keyFrames: keyFrames, duration: duration, detectedStrokes: detectedStrokes)
    }

    // MARK: - Pose Detection

    private func detectPose(in pixelBuffer: CVPixelBuffer, frameIndex: Int, timestamp: Double) async throws -> FramePoseData? {
        let request = VNDetectHumanBodyPoseRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else { return nil }

        var joints: [JointData] = []
        for jointName in JointMapping.allJoints {
            guard let point = try? observation.recognizedPoint(jointName),
                  point.confidence > AppConstants.Analysis.poseConfidenceThreshold else { continue }

            joints.append(JointData(
                name: JointMapping.canonicalName(for: jointName),
                x: Double(point.location.x),
                y: Double(point.location.y),
                confidence: point.confidence
            ))
        }

        guard joints.count >= 8 else { return nil }

        let avgConfidence = joints.map(\.confidence).reduce(0, +) / Float(joints.count)

        return FramePoseData(
            frameIndex: frameIndex,
            timestamp: timestamp,
            joints: joints,
            confidence: avgConfidence
        )
    }

    // MARK: - Stroke Apex Detection

    private let minTimeBetweenStrokes: Double = 1.5

    private func calculateWristVelocity(current: FramePoseData, previous: FramePoseData?) -> Double {
        guard let prev = previous else { return 0 }

        let wristName = Handedness.current.dominantWrist
        let currentWrist = current.joints.first { $0.name == wristName }
        let prevWrist = prev.joints.first { $0.name == wristName }

        guard let cw = currentWrist, let pw = prevWrist else { return 0 }

        let dx = cw.x - pw.x
        let dy = cw.y - pw.y
        let dt = current.timestamp - prev.timestamp

        guard dt > 0 else { return 0 }
        return sqrt(dx * dx + dy * dy) / dt
    }

    // MARK: - Key Frame Extraction

    private func extractEvenlySpacedKeyFrames(from url: URL, count: Int, duration: Double) async throws -> [(timestamp: Double, image: UIImage)] {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 480)

        let interval = duration / Double(count + 1)
        var results: [(timestamp: Double, image: UIImage)] = []

        for i in 1...count {
            let time = CMTime(seconds: interval * Double(i), preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                results.append((timestamp: time.seconds, image: UIImage(cgImage: cgImage)))
            } catch {
                continue
            }
        }

        return results
    }

    // MARK: - Helpers

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}
