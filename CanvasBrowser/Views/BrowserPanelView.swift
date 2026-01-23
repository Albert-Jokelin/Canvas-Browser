import SwiftUI
import WebKit

struct BrowserPanelView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var coordinator = WebViewCoordinator()
    @State private var urlString: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            
            if let currentTab = appState.sessionManager.currentTab,
               case .web(let webTab) = currentTab {
                   
                BrowserToolbar(
                    coordinator: coordinator,
                    currentURLString: $urlString,
                    onNavigate: { url in
                        coordinator.load(url)
                    }
                )
                .onAppear {
                    urlString = webTab.url.absoluteString
                }
                .onChange(of: coordinator.currentURL) { _, newURL in
                    if let newURL = newURL {
                        urlString = newURL.absoluteString
                    }
                }
                
                WebViewWrapper(coordinator: coordinator, tab: webTab)
                    .onAppear {
                        // Sync
                    }
            } else {
                 EmptyStateView()
            }
        }
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

