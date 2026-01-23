import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var coordinator: WebViewCoordinator
    @Binding var currentURLString: String
    var onNavigate: (URL) -> Void

    var body: some View {
        HStack(spacing: CanvasSpacing.md) {
            // Navigation Controls
            HStack(spacing: CanvasSpacing.sm) {
                Button(action: { coordinator.goBack() }) {
                    Image(systemName: CanvasSymbols.back)
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(!coordinator.canGoBack)
                .buttonStyle(CanvasIconButtonStyle())

                Button(action: { coordinator.goForward() }) {
                    Image(systemName: CanvasSymbols.forward)
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(!coordinator.canGoForward)
                .buttonStyle(CanvasIconButtonStyle())

                if coordinator.isLoading {
                    Button(action: { coordinator.stopLoading() }) {
                        Image(systemName: CanvasSymbols.stop)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(CanvasIconButtonStyle())
                } else {
                    Button(action: { coordinator.reload() }) {
                        Image(systemName: CanvasSymbols.refresh)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(CanvasIconButtonStyle())
                }
            }

            // Security indicator
            Image(systemName: coordinator.securityLevel.icon)
                .foregroundColor(coordinator.securityLevel.color)
                .font(.system(size: 12))

            // Address Bar
            TextField("Search or enter address", text: $currentURLString)
                .textFieldStyle(.plain)
                .padding(CanvasSpacing.sm)
                .background(Color.canvasSecondaryBackground)
                .cornerRadius(CanvasRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: CanvasRadius.medium)
                        .stroke(Color.canvasDivider.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: CanvasShadow.small.color, radius: CanvasShadow.small.radius, y: CanvasShadow.small.y)
                .onSubmit {
                    if let url = fixURL(currentURLString) {
                        onNavigate(url)
                    }
                }

            // Action buttons
            HStack(spacing: CanvasSpacing.xs) {
                Button(action: { coordinator.takeScreenshot() }) {
                    Image(systemName: "camera")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CanvasIconButtonStyle())
                .help("Take Screenshot")

                Button(action: {
                    NotificationCenter.default.post(name: ShortcutManager.addBookmarkNotification, object: nil)
                }) {
                    Image(systemName: CanvasSymbols.bookmarks)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CanvasIconButtonStyle())
                .help("Add Bookmark")

                Button(action: {
                    // Share sheet
                }) {
                    Image(systemName: CanvasSymbols.share)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CanvasIconButtonStyle())
                .help("Share")
            }
        }
        .padding(.horizontal, CanvasSpacing.lg)
        .padding(.vertical, CanvasSpacing.md)
        .background(CanvasToolbarBackground())
        .overlay(Divider(), alignment: .bottom)
        // Handle shortcut notifications
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.reloadNotification)) { notification in
            if notification.userInfo?["ignoreCache"] as? Bool == true {
                coordinator.reloadIgnoringCache()
            } else {
                coordinator.reload()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.goBackNotification)) { _ in
            coordinator.goBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.goForwardNotification)) { _ in
            coordinator.goForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.zoomInNotification)) { _ in
            coordinator.zoomIn()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.zoomOutNotification)) { _ in
            coordinator.zoomOut()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.zoomResetNotification)) { _ in
            coordinator.resetZoom()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.openInspectorNotification)) { _ in
            coordinator.openWebInspector()
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.printNotification)) { _ in
            coordinator.printPage()
        }
    }

    private func fixURL(_ input: String) -> URL? {
        if input.starts(with: "http") {
            return URL(string: input)
        } else if input.contains(".") && !input.contains(" ") {
            return URL(string: "https://" + input)
        } else {
            return URL(string: "https://www.google.com/search?q=" + (input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input))
        }
    }
}
