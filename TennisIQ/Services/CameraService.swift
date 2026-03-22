import AVFoundation
import AVFAudio
import UIKit
import Combine

/// Delegate protocol for receiving live video frames during recording
protocol CameraFrameDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutputPixelBuffer pixelBuffer: CVPixelBuffer, timestamp: CMTime)
}

final class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var error: CameraError?

    /// Set this delegate to receive live video frames during recording
    weak var frameDelegate: CameraFrameDelegate?

    private var captureSession: AVCaptureSession?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var timer: Timer?
    private var currentVideoURL: URL?
    private var recordingStartTime: Date?

    private let sessionQueue = DispatchQueue(label: "com.tennique.camera.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.tennique.camera.videoOutput", qos: .userInitiated)

    /// Controls whether live frame output is active (set to true when live mode is on)
    var liveFrameOutputEnabled = false

    /// Only process every Nth frame to keep CPU usage reasonable
    private var frameCount = 0
    private let frameSkipInterval = 4 // Process every 4th frame (~15fps from 60fps)

    private var completionHandler: ((Result<URL, CameraError>) -> Void)?

    enum CameraError: LocalizedError {
        case unauthorized
        case setupFailed(String)
        case recordingFailed(String)
        case deviceUnavailable

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Camera access is required to record tennis sessions."
            case .setupFailed(let msg):
                return "Camera setup failed: \(msg)"
            case .recordingFailed(let msg):
                return "Recording failed: \(msg)"
            case .deviceUnavailable:
                return "No camera available on this device."
            }
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            await MainActor.run { self.error = .unauthorized }
            return false
        }
    }

    // MARK: - Session Setup

    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
    }

    @MainActor
    func setupSession() async throws {
        guard await requestAuthorization() else {
            throw CameraError.unauthorized
        }

        configureAudioSession()

        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let videoDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw CameraError.deviceUnavailable
        }

        // Configure for 60fps if available
        try configureFrameRate(device: videoDevice, desiredFPS: AppConstants.Camera.defaultFPS)

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else {
            throw CameraError.setupFailed("Cannot add video input")
        }
        session.addInput(videoInput)

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        // Movie file output (for saving the recording)
        let output = AVCaptureMovieFileOutput()
        output.maxRecordedDuration = CMTime(
            seconds: AppConstants.Camera.maxRecordingDuration,
            preferredTimescale: 600
        )
        guard session.canAddOutput(output) else {
            throw CameraError.setupFailed("Cannot add movie output")
        }
        session.addOutput(output)

        // Video data output (for live frame analysis)
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        dataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(dataOutput) {
            session.addOutput(dataOutput)
            self.videoDataOutput = dataOutput
        }

        self.captureSession = session
        self.movieOutput = output

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        self.previewLayer = layer

        Task.detached { [weak session] in
            session?.startRunning()
        }
    }

    private func configureFrameRate(device: AVCaptureDevice, desiredFPS: Int) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        let targetFPS = CMTime(value: 1, timescale: CMTimeScale(desiredFPS))
        for range in device.activeFormat.videoSupportedFrameRateRanges {
            if range.maxFrameRate >= Double(desiredFPS) {
                device.activeVideoMinFrameDuration = targetFPS
                device.activeVideoMaxFrameDuration = targetFPS
                return
            }
        }
    }

    // MARK: - Recording

    func startRecording(completion: @escaping (Result<URL, CameraError>) -> Void) {
        guard let output = movieOutput, !output.isRecording else { return }

        let filename = "tennis_\(UUID().uuidString).mov"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        currentVideoURL = url
        completionHandler = completion
        recordingStartTime = Date()
        frameCount = 0

        output.startRecording(to: url, recordingDelegate: self)
        isRecording = true
        startTimer()
    }

    func stopRecording() {
        movieOutput?.stopRecording()
        isRecording = false
        liveFrameOutputEnabled = false
        stopTimer()
    }

    // MARK: - Timer

    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Cleanup

    func teardown() {
        stopRecording()
        // Dispatch stopRunning to a background queue to avoid blocking the main thread
        let session = captureSession
        captureSession = nil
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            if let error {
                self?.completionHandler?(.failure(.recordingFailed(error.localizedDescription)))
            } else {
                self?.completionHandler?(.success(outputFileURL))
            }
            self?.completionHandler = nil
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Live Frame Analysis)

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Only process frames when recording AND live mode is enabled
        guard isRecording, liveFrameOutputEnabled else { return }

        // Skip frames to maintain ~15fps processing rate
        frameCount += 1
        guard frameCount % frameSkipInterval == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        frameDelegate?.cameraService(self, didOutputPixelBuffer: pixelBuffer, timestamp: timestamp)
    }
}
