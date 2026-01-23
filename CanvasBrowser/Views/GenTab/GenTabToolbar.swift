import SwiftUI

struct GenTabToolbar: View {
    let actions: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(actions, id: \.self) { action in
                    Button(action: { }) {
                        Text(action)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Capsule()
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: Color.primary.opacity(0.08), radius: 2, y: 1)
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color.gray.opacity(0.05))
    }
}
