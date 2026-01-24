import Foundation
import WebKit
import Combine

class BrowsingSession: ObservableObject {
    @Published var activeTabs: [TabItem] = []
    @Published var currentTabId: UUID?

    // In-memory cache of webviews
    var webViewCache: [UUID: WKWebView] = [:]

    // Cache of coordinators to preserve tab state across switches
    var coordinatorCache: [UUID: WebViewCoordinator] = [:]

    /// Get or create a coordinator for a tab
    func coordinator(for tabId: UUID) -> WebViewCoordinator {
        if let existing = coordinatorCache[tabId] {
            return existing
        }

        // Check if this is a private tab
        let isPrivate = activeTabs.first { $0.id == tabId }.map { tab -> Bool in
            if case .web(let webTab) = tab {
                return webTab.isPrivate
            }
            return false
        } ?? false

        let new = WebViewCoordinator(isPrivate: isPrivate)
        coordinatorCache[tabId] = new
        return new
    }
    
    enum TabItem: Identifiable, Codable {
        case web(WebTab)
        case gen(GenTab)
        
        var id: UUID {
            switch self {
            case .web(let tab): return tab.id
            case .gen(let tab): return tab.id
            }
        }
        
        var title: String {
            switch self {
            case .web(let tab): return tab.title
            case .gen(let tab): return tab.title
            }
        }
    }
    
    struct WebTab: Identifiable, Codable {
        let id: UUID
        var url: URL
        var title: String
        var lastActive: Date
        var savedState: Data?
        var isPrivate: Bool

        init(url: URL, isPrivate: Bool = false) {
            self.id = UUID()
            self.url = url
            self.title = isPrivate ? "Private Tab" : "New Tab"
            self.lastActive = Date()
            self.isPrivate = isPrivate
        }
    }
    
    func addTab(url: URL, isPrivate: Bool = false) {
        let newTab = WebTab(url: url, isPrivate: isPrivate)
        activeTabs.append(.web(newTab))
        currentTabId = newTab.id
    }

    /// Add a new private browsing tab
    func addPrivateTab(url: URL = URL(string: "about:blank")!) {
        addTab(url: url, isPrivate: true)
    }
    
    func addGenTab(_ genTab: GenTab) {
        activeTabs.append(.gen(genTab))
        currentTabId = genTab.id
    }
    
    func closeTab(id: UUID) {
        activeTabs.removeAll { $0.id == id }
        webViewCache.removeValue(forKey: id)
        coordinatorCache.removeValue(forKey: id)
        if currentTabId == id {
            currentTabId = activeTabs.last?.id
        }
    }
    
    var currentTab: TabItem? {
        activeTabs.first { $0.id == currentTabId }
    }

    /// Get all web tabs (excludes GenTabs)
    func getAllWebTabs() -> [WebTab] {
        activeTabs.compactMap { tabItem in
            if case .web(let webTab) = tabItem {
                return webTab
            }
            return nil
        }
    }

    /// Get web tabs with their associated WebViews
    func getWebTabsWithViews() -> [(id: UUID, webView: WKWebView)] {
        getAllWebTabs().compactMap { webTab in
            guard let webView = webViewCache[webTab.id] else { return nil }
            return (id: webTab.id, webView: webView)
        }
    }

    /// Update a web tab's title
    func updateTabTitle(id: UUID, title: String) {
        if let index = activeTabs.firstIndex(where: { $0.id == id }) {
            if case .web(var webTab) = activeTabs[index] {
                webTab.title = title
                activeTabs[index] = .web(webTab)
            }
        }
    }

    /// Update a web tab's URL (triggers navigation)
    func updateTabURL(id: UUID, url: URL) {
        if let index = activeTabs.firstIndex(where: { $0.id == id }) {
            if case .web(var webTab) = activeTabs[index] {
                webTab.url = url
                activeTabs[index] = .web(webTab)
            }
        }
    }

    /// Update a GenTab (after AI modification)
    func updateGenTab(_ genTab: GenTab) {
        if let index = activeTabs.firstIndex(where: { $0.id == genTab.id }) {
            activeTabs[index] = .gen(genTab)
        }
    }

    // Persistence Logic
    func saveSession() {
        print("Saving session with \(activeTabs.count) tabs")
    }
}
