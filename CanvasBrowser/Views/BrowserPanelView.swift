import SwiftUI
import WebKit

struct BrowserPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var urlString: String = ""

    var body: some View {
        VStack(spacing: 0) {
            if let currentTab = appState.sessionManager.currentTab,
               case .web(let webTab) = currentTab {
                // Show start page for about:blank
                if webTab.url.absoluteString == "about:blank" {
                    NewTabStartPage(onNavigate: { url in
                        // Update the tab URL and load it
                        appState.sessionManager.updateTabURL(id: webTab.id, url: url)
                    })
                } else {
                    // Use the tab ID to get or create a coordinator
                    TabWebView(
                        tabId: webTab.id,
                        initialURL: webTab.url,
                        urlString: $urlString,
                        onTitleChange: { title in
                            appState.sessionManager.updateTabTitle(id: webTab.id, title: title)
                        },
                        onWebViewReady: { webView in
                            appState.sessionManager.webViewCache[webTab.id] = webView
                        }
                    )
                    .id(webTab.id) // Force view recreation for each tab
                }
            } else {
                EmptyStateView()
            }
        }
    }
}

/// A view that manages a single tab's web view
struct TabWebView: View {
    let tabId: UUID
    let initialURL: URL
    @Binding var urlString: String
    let onTitleChange: (String) -> Void
    let onWebViewReady: (WKWebView) -> Void

    // Use the cached coordinator from session manager
    @EnvironmentObject var appState: AppState

    private var coordinator: WebViewCoordinator {
        appState.sessionManager.coordinator(for: tabId)
    }

    @State private var hasLoadedInitialURL = false

    var body: some View {
        let coord = coordinator // Capture for use in closures

        VStack(spacing: 0) {
            BrowserToolbar(
                coordinator: coord,
                currentURLString: $urlString,
                onNavigate: { url in
                    coord.load(url)
                }
            )

            CachedWebViewContainer(
                coordinator: coord,
                initialURL: initialURL,
                hasLoaded: $hasLoadedInitialURL
            )
            .onAppear {
                // Update URL string from coordinator's current URL if available
                if let currentURL = coord.currentURL {
                    urlString = currentURL.absoluteString
                } else {
                    urlString = initialURL.absoluteString
                }
                onWebViewReady(coord.getWebView())
            }
        }
        .onReceive(coord.$pageURL) { newURL in
            if let newURL = newURL {
                urlString = newURL.absoluteString
            }
        }
        .onReceive(coord.$pageTitle) { newTitle in
            if !newTitle.isEmpty {
                onTitleChange(newTitle)
            }
        }
    }
}

/// WebView container that preserves state across tab switches
struct CachedWebViewContainer: NSViewRepresentable {
    let coordinator: WebViewCoordinator
    let initialURL: URL
    @Binding var hasLoaded: Bool

    func makeNSView(context: Context) -> WKWebView {
        let webView = coordinator.getWebView()

        // Only load the initial URL if we haven't loaded anything yet
        if !hasLoaded && coordinator.currentURL == nil {
            coordinator.load(initialURL)
            DispatchQueue.main.async {
                hasLoaded = true
            }
        }

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // WebView is managed by coordinator - no updates needed
    }
}

struct WebViewWrapper: NSViewRepresentable {
    @ObservedObject var coordinator: WebViewCoordinator
    let tab: BrowsingSession.WebTab
    
    func makeNSView(context: Context) -> WKWebView {
        return coordinator.createWebView(for: tab)
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Handle updates if needed
        coordinator.setActive(nsView)

        // Check if URL changed externally (e.g. from address bar if specific logic used)
        // But usually address bar calls coordinator.load() which calls webview.load()
    }
}

// MARK: - New Tab Start Page

struct NewTabStartPage: View {
    let onNavigate: (URL) -> Void
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Logo
                Image(systemName: "safari")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Canvas Browser")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search or enter URL", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($isSearchFocused)
                        .onSubmit {
                            navigateToInput()
                        }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .frame(maxWidth: 500)

                // Quick links
                HStack(spacing: 16) {
                    QuickLinkButton(title: "Google", icon: "magnifyingglass", color: .blue) {
                        onNavigate(URL(string: "https://google.com")!)
                    }
                    QuickLinkButton(title: "YouTube", icon: "play.rectangle.fill", color: .red) {
                        onNavigate(URL(string: "https://youtube.com")!)
                    }
                    QuickLinkButton(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right", color: .purple) {
                        onNavigate(URL(string: "https://github.com")!)
                    }
                    QuickLinkButton(title: "Reddit", icon: "bubble.left.and.bubble.right.fill", color: .orange) {
                        onNavigate(URL(string: "https://reddit.com")!)
                    }
                }
            }
            .padding(40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isSearchFocused = true
        }
    }

    private func navigateToInput() {
        let input = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        if input.starts(with: "http://") || input.starts(with: "https://") {
            if let url = URL(string: input) {
                onNavigate(url)
            }
        } else if input.contains(".") && !input.contains(" ") {
            if let url = URL(string: "https://" + input) {
                onNavigate(url)
            }
        } else {
            // Search query
            let encoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                onNavigate(url)
            }
        }
    }
}

struct QuickLinkButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                    .frame(width: 56, height: 56)
                    .background(color.opacity(0.1))
                    .cornerRadius(12)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

