import Foundation
import SwiftUI
import SwiftData
import AVFoundation
import Vision
import Combine

@MainActor
final class RecordViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isSessionReady = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var error: CameraService.CameraError?
    @Published var lastSavedSession: SessionModel?
    @Published var showSessionSaved = false

    let cameraService = CameraService()
    private var timerCancellable: AnyCancellable?
    private var recordingStartTime: Date?
    private var modelContext: ModelContext?

    /// Bridge to LiveSwingAnalyzer — set from RecordView
    weak var liveAnalyzer: LiveSwingAnalyzer?

    private let poseQueue = DispatchQueue(label: "com.tennique.record.pose", qos: .userInitiated)
    private var frameIndex = 0

    var formattedDuration: String {
        let total = Int(recordingDuration)
        let minutes = total / 60
        let seconds = total % 60
        let tenths = Int((recordingDuration - Double(total)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }

    func setup() async {
        do {
            cameraService.frameDelegate = self
            try await cameraService.setupSession()
            isSessionReady = true
        } catch let err as CameraService.CameraError {
            error = err
        } catch {
            self.error = .setupFailed(error.localizedDescription)
        }
    }

    func startRecording(context: ModelContext) {
        modelContext = context
        recordingStartTime = Date()
        recordingDuration = 0
        frameIndex = 0

        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }

        cameraService.startRecording { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let url):
                    self.saveSession(videoURL: url)
                case .failure(let err):
                    self.error = err
                }
            }
        }
        isRecording = true
    }

    func stopRecording() {
        cameraService.stopRecording()
        isRecording = false
        timerCancellable?.cancel()
        timerCancellable = nil
        liveAnalyzer?.reset()
    }

    /// Enable/disable live frame output for real-time analysis
    func setLiveMode(_ enabled: Bool) {
        cameraService.liveFrameOutputEnabled = enabled
        if !enabled {
            liveAnalyzer?.reset()
        }
    }

    func teardown() {
        stopRecording()
        cameraService.teardown()
        isSessionReady = false
    }

    func dismissSavedOverlay() {
        showSessionSaved = false
        lastSavedSession = nil
    }

    private func saveSession(videoURL: URL) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "session_\(UUID().uuidString).mov"
        let destinationURL = documentsURL.appendingPathComponent(filename)

        do {
            try FileManager.default.moveItem(at: videoURL, to: destinationURL)

            let duration = Int(recordingDuration)
            let session = SessionModel(
                recordedAt: recordingStartTime ?? Date(),
                durationSeconds: duration,
                status: .processing,
                videoLocalURL: filename
            )
            modelContext?.insert(session)
            try? modelContext?.save()

            lastSavedSession = session
            showSessionSaved = true

            // Auto-start analysis in the background immediately after saving
            if let context = modelContext {
                let vm = AnalysisViewModel(session: session)
                Task {
                    await vm.triggerAnalysis(context: context)
                }
            }
        } catch {
            self.error = .recordingFailed("Failed to save video: \(error.localizedDescription)")
        }
    }
}

// MARK: - Live Frame Processing (Camera → Vision → LiveSwingAnalyzer)

extension RecordViewModel: CameraFrameDelegate {
    nonisolated func cameraService(_ service: CameraService, didOutputPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // Run pose detection on the background queue
        poseQueue.async { [weak self] in
            guard let self else { return }

            let request = VNDetectHumanBodyPoseRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

            do {
                try handler.perform([request])
            } catch {
                return // Skip frame on failure
            }

            guard let observation = request.results?.first else { return }

            // Extract joints
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

            guard joints.count >= 8 else { return }

            let currentIdx = self.frameIndex
            self.frameIndex += 1

            let avgConfidence = joints.map(\.confidence).reduce(0, +) / Float(joints.count)
            let poseData = FramePoseData(
                frameIndex: currentIdx,
                timestamp: timestamp.seconds,
                joints: joints,
                confidence: avgConfidence
            )

            // Feed to LiveSwingAnalyzer on main thread
            DispatchQueue.main.async { [weak self] in
                self?.liveAnalyzer?.processFrame(poseData)
            }
        }
    }
}
