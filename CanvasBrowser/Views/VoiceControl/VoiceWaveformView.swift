import SwiftUI

struct VoiceWaveformView: View {
    let audioLevel: Float
    let barCount: Int = 3

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.canvasRed)
                    .frame(width: 3, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.15)
                            .delay(Double(index) * 0.05),
                        value: audioLevel
                    )
            }
        }
        .frame(height: 16)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 16
        let multipliers: [Float] = [0.7, 1.0, 0.5]
        let multiplier = index < multipliers.count ? multipliers[index] : 0.5
        let level = CGFloat(audioLevel * multiplier)
        return baseHeight + (maxHeight - baseHeight) * level
    }
}
