import SwiftUI

struct BrowserToolbar: View {
    @ObservedObject var coordinator: WebViewCoordinator
    @Binding var currentURLString: String
    var onNavigate: (URL) -> Void
    @State private var showSecurityDetails = false

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

            // Security indicator with popover
            Button(action: { showSecurityDetails.toggle() }) {
                Image(systemName: coordinator.securityLevel.icon)
                    .foregroundColor(coordinator.securityLevel.color)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSecurityDetails, arrowEdge: .bottom) {
                SecurityDetailsView(
                    securityLevel: coordinator.securityLevel,
                    url: coordinator.currentURL
                )
            }
            .help("View site security info")

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
                Button(action: {
                    NotificationCenter.default.post(name: ShortcutManager.addBookmarkNotification, object: nil)
                }) {
                    Image(systemName: CanvasSymbols.bookmarks)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CanvasIconButtonStyle())
                .help("Add Bookmark (⌘D)")

                Button(action: {
                    // Share using system share sheet
                    if let url = URL(string: currentURLString) {
                        let picker = NSSharingServicePicker(items: [url])
                        if let window = NSApp.keyWindow,
                           let contentView = window.contentView {
                            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                        }
                    }
                }) {
                    Image(systemName: CanvasSymbols.share)
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(CanvasIconButtonStyle())
                .help("Share (⌘⇧S)")
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

// MARK: - Security Details View

struct SecurityDetailsView: View {
    let securityLevel: WebViewCoordinator.SecurityLevel
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: securityLevel.icon)
                    .font(.system(size: 20))
                    .foregroundColor(securityLevel.color)

                Text(securityLevel.title)
                    .font(.headline)
            }

            Divider()

            // Details
            VStack(alignment: .leading, spacing: 8) {
                if let url = url {
                    // Domain
                    HStack {
                        Text("Domain:")
                            .foregroundColor(.secondary)
                        Text(url.host ?? "Unknown")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)

                    // Protocol
                    HStack {
                        Text("Protocol:")
                            .foregroundColor(.secondary)
                        Text(url.scheme?.uppercased() ?? "Unknown")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }

                // Security description
                Text(securityLevel.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if securityLevel == .secure {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Connection is secure")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else if securityLevel == .insecure {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Connection is not secure")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}

extension WebViewCoordinator.SecurityLevel {
    var title: String {
        switch self {
        case .secure: return "Secure Connection"
        case .insecure: return "Not Secure"
        case .unknown: return "Unknown"
        }
    }

    var description: String {
        switch self {
        case .secure:
            return "This site uses HTTPS encryption to protect your data."
        case .insecure:
            return "This site does not use encryption. Information you send may be visible to others."
        case .unknown:
            return "Unable to determine connection security."
        }
    }
}
