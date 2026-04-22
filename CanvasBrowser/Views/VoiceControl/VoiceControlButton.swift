import SwiftUI

struct VoiceControlButton: View {
    @ObservedObject var voiceService: VoiceControlService
    @State private var isPulsing = false

    var body: some View {
        Button(action: {
            voiceService.toggleListening()
        }) {
            ZStack {
                if voiceService.isListening {
                    Circle()
                        .fill(Color.canvasRed.opacity(0.2))
                        .frame(width: 28, height: 28)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.6)
                        .animation(
                            .easeInOut(duration: 1.0).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                    .foregroundColor(voiceService.isListening ? .canvasRed : .secondary)
            }
        }
        .help(voiceService.isListening ? "Stop Voice Control" : "Start Voice Control (⌥V)")
        .onChange(of: voiceService.isListening) { _, newValue in
            isPulsing = newValue
        }
    }
}
