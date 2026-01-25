import WidgetKit
import SwiftUI

// MARK: - Widget Bundle

@main
struct CanvasBrowserWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentGenTabsWidget()
        BookmarksWidget()
        QuickActionsWidget()
    }
}

// MARK: - Shared Data Provider

struct WidgetDataProvider {
    static let appGroupID = "group.com.canvas.browser"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func getRecentGenTabs() -> [GenTabEntry] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "widget_recent_gentabs"),
              let entries = try? JSONDecoder().decode([GenTabEntry].self, from: data) else {
            return GenTabEntry.placeholder
        }
        return entries
    }

    static func getBookmarks() -> [BookmarkEntry] {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: "widget_bookmarks"),
              let entries = try? JSONDecoder().decode([BookmarkEntry].self, from: data) else {
            return BookmarkEntry.placeholder
        }
        return entries
    }
}

// MARK: - Widget Entry Models

struct GenTabEntry: Codable, Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let preview: String
    let date: Date

    static var placeholder: [GenTabEntry] {
        [
            GenTabEntry(id: UUID(), title: "Weather Report", icon: "cloud.sun", preview: "Today's forecast", date: Date()),
            GenTabEntry(id: UUID(), title: "Recipe Ideas", icon: "fork.knife", preview: "Quick dinner recipes", date: Date()),
            GenTabEntry(id: UUID(), title: "Travel Guide", icon: "airplane", preview: "Best destinations", date: Date())
        ]
    }
}

struct BookmarkEntry: Codable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let favicon: String?

    static var placeholder: [BookmarkEntry] {
        [
            BookmarkEntry(id: UUID(), title: "GitHub", url: "https://github.com", favicon: nil),
            BookmarkEntry(id: UUID(), title: "Apple", url: "https://apple.com", favicon: nil),
            BookmarkEntry(id: UUID(), title: "News", url: "https://news.ycombinator.com", favicon: nil)
        ]
    }
}
