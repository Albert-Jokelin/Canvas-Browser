import SwiftUI

struct SidebarRail: View {
    @EnvironmentObject var appState: AppState
    @Binding var showChat: Bool
    @State private var hoveredButton: String?

    var body: some View {
        VStack(spacing: CanvasSpacing.lg) {
            // Top Actions
            Group {
                RailButton(
                    icon: CanvasSymbols.newTab,
                    label: "New Tab",
                    isHovered: hoveredButton == "new",
                    accentColor: .canvasBlue
                ) {
                    appState.sessionManager.addTab(url: URL(string: "https://google.com")!)
                }
                .onHover { hoveredButton = $0 ? "new" : nil }

                RailButton(
                    icon: CanvasSymbols.search,
                    label: "Search",
                    isHovered: hoveredButton == "search",
                    accentColor: .canvasIndigo
                ) {
                    appState.sessionManager.addTab(url: URL(string: "about:blank")!)
                }
                .onHover { hoveredButton = $0 ? "search" : nil }

                RailButton(
                    icon: CanvasSymbols.aiChat,
                    label: "Chat",
                    isHovered: hoveredButton == "chat",
                    accentColor: .canvasTeal,
                    isActive: showChat
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        showChat.toggle()
                    }
                }
                .onHover { hoveredButton = $0 ? "chat" : nil }
            }
            .padding(.top, CanvasSpacing.lg)

            Divider()
                .frame(width: 32)
                .padding(.vertical, CanvasSpacing.xs)

            Spacer()

            // Bottom Actions
            VStack(spacing: CanvasSpacing.md) {
                RailButton(
                    icon: CanvasSymbols.history,
                    label: "History",
                    isHovered: hoveredButton == "history",
                    accentColor: .canvasOrange
                ) {
                    NotificationCenter.default.post(name: ShortcutManager.showHistoryNotification, object: nil)
                }
                .onHover { hoveredButton = $0 ? "history" : nil }

                if #available(macOS 14.0, *) {
                    SettingsLink {
                        RailButtonContent(
                            icon: CanvasSymbols.settings,
                            isHovered: hoveredButton == "settings",
                            accentColor: .canvasSecondaryLabel
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hoveredButton = $0 ? "settings" : nil }
                    .help("Settings")
                } else {
                    RailButton(
                        icon: CanvasSymbols.settings,
                        label: "Settings",
                        isHovered: hoveredButton == "settings",
                        accentColor: .canvasSecondaryLabel
                    ) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .onHover { hoveredButton = $0 ? "settings" : nil }
                }
            }
            .padding(.bottom, CanvasSpacing.lg)
        }
        .frame(width: 60)
    }
}

struct RailButton: View {
    let icon: String
    let label: String
    let isHovered: Bool
    let accentColor: Color
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RailButtonContent(
                icon: icon,
                isHovered: isHovered,
                accentColor: accentColor,
                isActive: isActive
            )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

struct RailButtonContent: View {
    let icon: String
    let isHovered: Bool
    let accentColor: Color
    var isActive: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CanvasRadius.medium)
                .fill(
                    isActive
                    ? accentColor.opacity(0.15)
                    : isHovered
                        ? Color.canvasLabel.opacity(0.08)
                        : Color.clear
                )
                .frame(width: 44, height: 44)

            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    isActive
                    ? accentColor
                    : isHovered
                        ? accentColor
                        : Color.canvasSecondaryLabel
                )
        }
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }
}
