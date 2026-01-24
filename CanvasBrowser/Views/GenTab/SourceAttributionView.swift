import SwiftUI

/// Displays source attributions for a GenTab, linking back to original web pages
struct SourceAttributionView: View {
    let sources: [SourceAttribution]
    var onSourceTap: ((SourceAttribution) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sources) { source in
                        SourceChip(source: source, onTap: {
                            if let onSourceTap = onSourceTap {
                                onSourceTap(source)
                            } else if let url = URL(string: source.url) {
                                NSWorkspace.shared.open(url)
                            }
                        })
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}

struct SourceChip: View {
    let source: SourceAttribution
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Favicon placeholder
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 20, height: 20)

                    Text(String(source.domain.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }

                Text(source.domain)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isHovered ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(source.title)
    }
}

// MARK: - Preview Support

#if DEBUG
struct SourceAttributionView_Previews: PreviewProvider {
    static var previews: some View {
        SourceAttributionView(sources: [
            SourceAttribution(url: "https://amazon.com/product/123", title: "MacBook Pro - Amazon", domain: "amazon.com"),
            SourceAttribution(url: "https://apple.com/macbook-pro", title: "MacBook Pro - Apple", domain: "apple.com"),
            SourceAttribution(url: "https://bestbuy.com/macbook", title: "MacBook Pro - Best Buy", domain: "bestbuy.com")
        ])
        .padding()
        .frame(width: 400)
    }
}
#endif
