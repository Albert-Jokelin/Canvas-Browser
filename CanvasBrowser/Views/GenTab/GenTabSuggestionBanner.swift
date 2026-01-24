import SwiftUI

/// A dismissible banner that appears when AI detects a GenTab opportunity
struct GenTabSuggestionBanner: View {
    let suggestion: IntentClassifier.Analysis
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var isGenerating = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.suggestedTitle ?? "Create GenTab?")
                    .font(.headline)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text("From \(suggestion.relatedTabIds.count) related tabs")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let category = suggestion.detectedCategory {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(category.rawValue)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Actions
            if isGenerating {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 80)
            } else {
                HStack(spacing: 8) {
                    Button(action: {
                        isGenerating = true
                        onAccept()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Create")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.small)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Compact version for menu bar or smaller spaces
struct GenTabSuggestionCompact: View {
    let suggestion: IntentClassifier.Analysis
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)

            Text(suggestion.suggestedTitle ?? "GenTab Available")
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Button("Create", action: onAccept)
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.mini)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
struct GenTabSuggestionBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GenTabSuggestionBanner(
                suggestion: IntentClassifier.Analysis(
                    shouldSuggestGenTab: true,
                    confidence: 0.85,
                    suggestedTitle: "MacBook Comparison",
                    relatedTabIds: [UUID(), UUID(), UUID(), UUID()],
                    reason: "Detected 4 shopping tabs",
                    detectedCategory: .shopping
                ),
                onAccept: { print("Accept") },
                onDismiss: { print("Dismiss") }
            )

            GenTabSuggestionCompact(
                suggestion: IntentClassifier.Analysis(
                    shouldSuggestGenTab: true,
                    confidence: 0.75,
                    suggestedTitle: "Trip Planner",
                    relatedTabIds: [UUID(), UUID(), UUID()],
                    reason: "Detected 3 travel tabs",
                    detectedCategory: .travel
                ),
                onAccept: { print("Accept") },
                onDismiss: { print("Dismiss") }
            )
        }
        .padding()
        .frame(width: 500)
    }
}
#endif
