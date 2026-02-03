import Foundation
import WebKit
import Combine
import OSLog

class BrowsingSession: ObservableObject {
    @Published var activeTabs: [TabItem] = []
    @Published var currentTabId: UUID?

    // In-memory cache of webviews
    var webViewCache: [UUID: WKWebView] = [:]

    // Cache of coordinators to preserve tab state across switches
    var coordinatorCache: [UUID: WebViewCoordinator] = [:]

    // MARK: - Persistence Keys
    private let sessionTabsKey = "canvas_session_tabs"
    private let sessionCurrentTabKey = "canvas_session_current_tab"

    // MARK: - Initialization

    init() {
        loadSession()
    }

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

        // Index in Spotlight
        SpotlightIndexManager.shared.indexGenTab(genTab)

        // Sync to widgets
        WidgetDataSync.shared.addGenTab(genTab)
    }

    func closeTab(id: UUID) {
        // Check if it's a GenTab being closed and remove from Spotlight/widgets
        if let tab = activeTabs.first(where: { $0.id == id }),
           case .gen(let genTab) = tab {
            SpotlightIndexManager.shared.removeGenTab(genTab)
            WidgetDataSync.shared.removeGenTab(genTab)
        }

        // Properly cleanup WebView resources BEFORE removing from cache
        if let webView = webViewCache[id] {
            // Stop all loading
            webView.stopLoading()
            
            // Remove all observers and delegates
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            
            // Clear website data for this webview
            let dataStore = webView.configuration.websiteDataStore
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date.distantPast
            ) {
                Logger.browser.debug("Cleared website data for closed tab")
            }
            
            // Explicitly clear user scripts to break retain cycles
            webView.configuration.userContentController.removeAllUserScripts()
        }
        
        // Cleanup coordinator
        if let coordinator = coordinatorCache[id] {
            coordinator.cleanup()
        }
        
        // Now remove from caches
        activeTabs.removeAll { $0.id == id }
        webViewCache.removeValue(forKey: id)
        coordinatorCache.removeValue(forKey: id)
        
        if currentTabId == id {
            currentTabId = activeTabs.last?.id
        }
        
        Logger.browser.info("Closed tab: \(id)")
    }
    
    var currentTab: TabItem? {
        activeTabs.first { $0.id == currentTabId }
    }

    /// Alias for activeTabs for consistency
    var tabs: [TabItem] {
        activeTabs
    }

    /// Switch to an existing GenTab
    func switchToGenTab(_ genTab: GenTab) {
        if activeTabs.contains(where: { $0.id == genTab.id }) {
            currentTabId = genTab.id
        }
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

    // MARK: - Persistence Logic

    /// Save the current session state to UserDefaults
    func saveSession() {
        // Only save non-private tabs
        let tabsToSave = activeTabs.filter { tab in
            if case .web(let webTab) = tab {
                return !webTab.isPrivate
            }
            return true
        }

        do {
            let encoder = JSONEncoder()
            let tabsData = try encoder.encode(tabsToSave)
            UserDefaults.standard.set(tabsData, forKey: sessionTabsKey)

            // Save current tab ID if it's not a private tab
            if let currentId = currentTabId,
               tabsToSave.contains(where: { $0.id == currentId }) {
                UserDefaults.standard.set(currentId.uuidString, forKey: sessionCurrentTabKey)
            } else {
                UserDefaults.standard.removeObject(forKey: sessionCurrentTabKey)
            }

            Logger.persistence.debug("Saved session with \(tabsToSave.count) tabs")
        } catch {
            Logger.persistence.error("Failed to save session: \(error.localizedDescription)")
            CrashReporter.shared.recordError(error, context: ["operation": "saveSession"])
        }
    }

    /// Load session state from UserDefaults
    func loadSession() {
        guard let tabsData = UserDefaults.standard.data(forKey: sessionTabsKey) else {
            Logger.persistence.info("No saved session found")
            return
        }

        do {
            let decoder = JSONDecoder()
            let loadedTabs = try decoder.decode([TabItem].self, from: tabsData)

            if !loadedTabs.isEmpty {
                activeTabs = loadedTabs

                // Restore current tab
                if let currentTabString = UserDefaults.standard.string(forKey: sessionCurrentTabKey),
                   let currentId = UUID(uuidString: currentTabString),
                   activeTabs.contains(where: { $0.id == currentId }) {
                    currentTabId = currentId
                } else {
                    currentTabId = activeTabs.first?.id
                }

                Logger.persistence.info("Restored session with \(loadedTabs.count) tabs")
            }
        } catch {
            Logger.persistence.error("Failed to load session: \(error.localizedDescription)")
            CrashReporter.shared.recordError(error, context: ["operation": "loadSession"])
        }
    }

    /// Clear saved session data
    func clearSavedSession() {
        UserDefaults.standard.removeObject(forKey: sessionTabsKey)
        UserDefaults.standard.removeObject(forKey: sessionCurrentTabKey)
    }
}
