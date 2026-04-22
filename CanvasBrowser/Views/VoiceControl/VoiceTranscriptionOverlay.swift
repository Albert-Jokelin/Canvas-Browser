import SwiftUI

struct VoiceTranscriptionOverlay: View {
    @ObservedObject var voiceService: VoiceControlService

    var body: some View {
        if voiceService.isListening || !voiceService.lastCommandFeedback.isEmpty {
            VStack {
                Spacer()
                overlayContent
                    .padding(.bottom, CanvasSpacing.lg)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: voiceService.isListening)
            .animation(.easeInOut(duration: 0.25), value: voiceService.lastCommandFeedback)
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if !voiceService.lastCommandFeedback.isEmpty {
            // Command feedback toast
            HStack(spacing: CanvasSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.canvasGreen)
                    .font(.system(size: 14))
                Text(voiceService.lastCommandFeedback)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.canvasLabel)
            }
            .padding(.horizontal, CanvasSpacing.lg)
            .padding(.vertical, CanvasSpacing.sm)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(Color.canvasGreen.opacity(0.3), lineWidth: 1)
            )
        } else if !voiceService.currentTranscription.isEmpty {
            // Live transcription
            HStack(spacing: CanvasSpacing.sm) {
                VoiceWaveformView(audioLevel: voiceService.audioLevel)
                Text(voiceService.currentTranscription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.canvasLabel)
                    .lineLimit(2)
            }
            .padding(.horizontal, CanvasSpacing.lg)
            .padding(.vertical, CanvasSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CanvasRadius.medium)
                    .stroke(Color.canvasRed.opacity(0.3), lineWidth: 1)
            )
            .frame(maxWidth: 400)
        } else {
            // Listening indicator
            HStack(spacing: CanvasSpacing.sm) {
                PulsingDot()
                Text("Listening...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.canvasSecondaryLabel)
            }
            .padding(.horizontal, CanvasSpacing.lg)
            .padding(.vertical, CanvasSpacing.sm)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule()
                    .stroke(Color.canvasRed.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

// MARK: - Pulsing Dot

private struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.canvasRed)
            .frame(width: 8, height: 8)
            .scaleEffect(isPulsing ? 1.3 : 0.8)
            .opacity(isPulsing ? 1.0 : 0.5)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
