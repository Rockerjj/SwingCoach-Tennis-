import SwiftUI
import AVFoundation

struct RecordView: View {
    @StateObject private var viewModel = RecordViewModel()
    @Environment(\.modelContext) private var modelContext
    let theme = DesignSystem.current
    var switchToSessions: () -> Void

    var body: some View {
        ZStack {
            if viewModel.showSessionSaved {
                sessionSavedScreen
            } else {
                cameraScreen
            }
        }
        .task {
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.teardown()
        }
        .alert(
            "Camera Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )
        ) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }

    // MARK: - Camera Screen

    private var cameraScreen: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            if viewModel.isSessionReady {
                CameraPreviewRepresentable(previewLayer: viewModel.cameraService.previewLayer)
                    .ignoresSafeArea()
                    .overlay {
                        if viewModel.isRecording {
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(theme.accent, lineWidth: 3)
                                .ignoresSafeArea()
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)
                        }
                    }
            } else {
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                        .tint(theme.accent)
                        .scaleEffect(1.2)
                    Text("Setting up camera...")
                        .font(AppFont.body(size: 16))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            VStack {
                Spacer()
                recordingControls
            }
            .padding(.bottom, Spacing.xxl)

            if viewModel.isRecording {
                timerOverlay
            }

            if !viewModel.isRecording && viewModel.isSessionReady {
                positioningGuide
            }

            VStack {
                HStack {
                    Button(action: { switchToSessions() }) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Sessions")
                                .font(AppFont.body(size: 14, weight: .medium))
                        }
                        .foregroundStyle(theme.textOnAccent)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.35))
                        )
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.leading, Spacing.md)
                    .opacity(viewModel.isRecording ? 0 : 1)
                    .disabled(viewModel.isRecording)

                    Spacer()
                }

                Spacer()
            }
        }
    }

    // MARK: - Session Saved Screen

    private var sessionSavedScreen: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(theme.success)

                VStack(spacing: Spacing.xs) {
                    Text("Session Saved!")
                        .font(AppFont.display(size: 28))
                        .foregroundStyle(theme.textPrimary)

                    Text("Your recording is ready for\nAI analysis")
                        .font(AppFont.body(size: 16))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                Spacer()

                VStack(spacing: Spacing.md) {
                    Button(action: {
                        viewModel.dismissSavedOverlay()
                        switchToSessions()
                    }) {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "list.bullet.rectangle.fill")
                                .font(.system(size: 16))
                            Text("View Sessions")
                        }
                        .font(AppFont.body(size: 17, weight: .semibold))
                        .foregroundStyle(theme.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .fill(theme.accent)
                        )
                    }

                    Button(action: { viewModel.dismissSavedOverlay() }) {
                        Text("Record Another")
                            .font(AppFont.body(size: 16, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: Radius.md)
                                    .stroke(theme.textTertiary.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
    }

    // MARK: - Positioning Guide

    private var positioningGuide: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "figure.tennis")
                .font(.system(size: 40))
                .foregroundStyle(theme.accent.opacity(0.6))

            Text("Position your phone \(AppConstants.Camera.recommendedDistance) away")
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textSecondary)

            Text("at \(AppConstants.Camera.recommendedHeight.lowercased())")
                .font(AppFont.body(size: 14))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(theme.surfacePrimary.opacity(0.85))
        )
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        HStack(spacing: Spacing.xxl) {
            if viewModel.isRecording {
                Button(action: { viewModel.stopRecording() }) {
                    ZStack {
                        Circle()
                            .fill(theme.error.opacity(0.2))
                            .frame(width: 80, height: 80)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.error)
                            .frame(width: 28, height: 28)
                    }
                }
            } else {
                Button(action: { viewModel.startRecording(context: modelContext) }) {
                    ZStack {
                        Circle()
                            .strokeBorder(theme.accent, lineWidth: 4)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(theme.accent)
                            .frame(width: 64, height: 64)
                    }
                }
                .disabled(!viewModel.isSessionReady)
                .opacity(viewModel.isSessionReady ? 1 : 0.4)
            }
        }
    }

    // MARK: - Timer Overlay

    private var timerOverlay: some View {
        VStack {
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(theme.error)
                    .frame(width: 10, height: 10)

                Text(viewModel.formattedDuration)
                    .font(AppFont.mono(size: 18))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(theme.surfacePrimary.opacity(0.8))
            )
            .padding(.top, Spacing.xxl)

            Spacer()
        }
    }
}

// MARK: - Camera Preview UIKit Bridge

struct CameraPreviewRepresentable: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer = previewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer = previewLayer
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()
            guard let previewLayer else { return }
            previewLayer.frame = bounds
            previewLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(previewLayer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
