import SwiftUI

/// Horizontal tab strip showing all open tabs
struct TabStrip: View {
    @EnvironmentObject var appState: AppState
    @State private var hoveredTabId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(appState.sessionManager.activeTabs) { tab in
                    TabStripItem(
                        tab: tab,
                        isSelected: tab.id == appState.sessionManager.currentTabId,
                        isHovered: hoveredTabId == tab.id,
                        onSelect: {
                            appState.sessionManager.currentTabId = tab.id
                        },
                        onClose: {
                            appState.sessionManager.closeTab(id: tab.id)
                        }
                    )
                    .onHover { isHovered in
                        hoveredTabId = isHovered ? tab.id : nil
                    }
                }

                // New tab button
                Button(action: {
                    appState.sessionManager.addTab(url: URL(string: "about:blank")!)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("New Tab (⌘T)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 32)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TabStripItem: View {
    let tab: BrowsingSession.TabItem
    let isSelected: Bool
    let isHovered: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Tab icon (purple for private tabs)
            Image(systemName: tabIcon)
                .font(.system(size: 11))
                .foregroundColor(iconColor)
                .frame(width: 14)

            // Tab title
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: 120, alignment: .leading)

            // Close button (visible on hover or when selected)
            if isHovered || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .opacity(isHovered ? 1 : 0)
                        )
                }
                .buttonStyle(.plain)
                .help("Close Tab")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                    ? Color(NSColor.controlBackgroundColor)
                    : isHovered
                        ? Color(NSColor.controlBackgroundColor).opacity(0.5)
                        : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var tabIcon: String {
        switch tab {
        case .web(let webTab):
            return webTab.isPrivate ? "hand.raised.fill" : "globe"
        case .gen:
            return "sparkles"
        }
    }

    private var isPrivateTab: Bool {
        if case .web(let webTab) = tab {
            return webTab.isPrivate
        }
        return false
    }

    private var iconColor: Color {
        if isPrivateTab {
            return .purple
        }
        return isSelected ? .accentColor : .secondary
    }
}

// MARK: - Preview

#if DEBUG
struct TabStrip_Previews: PreviewProvider {
    static var previews: some View {
        TabStrip()
            .environmentObject(AppState())
            .frame(width: 600)
    }
}
#endif
