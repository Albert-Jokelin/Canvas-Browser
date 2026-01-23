import Foundation
import WebKit
import Combine

class BrowsingSession: ObservableObject {
    @Published var activeTabs: [TabItem] = []
    @Published var currentTabId: UUID?
    
    // In-memory cache of webviews
    var webViewCache: [UUID: WKWebView] = [:]
    
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
        
        init(url: URL) {
            self.id = UUID()
            self.url = url
            self.title = "New Tab"
            self.lastActive = Date()
        }
    }
    
    func addTab(url: URL) {
        let newTab = WebTab(url: url)
        activeTabs.append(.web(newTab))
        currentTabId = newTab.id
    }
    
    func addGenTab(_ genTab: GenTab) {
        activeTabs.append(.gen(genTab))
        currentTabId = genTab.id
    }
    
    func closeTab(id: UUID) {
        activeTabs.removeAll { $0.id == id }
        webViewCache.removeValue(forKey: id)
        if currentTabId == id {
            currentTabId = activeTabs.last?.id
        }
    }
    
    var currentTab: TabItem? {
        activeTabs.first { $0.id == currentTabId }
    }
    
    // Persistence Logic
    func saveSession() {
        print("Saving session with \(activeTabs.count) tabs")
    }
}
