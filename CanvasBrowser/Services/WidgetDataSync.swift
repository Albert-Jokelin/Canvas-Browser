import Foundation
import WidgetKit

/// Syncs app data with widgets through App Groups
class WidgetDataSync {
    static let shared = WidgetDataSync()

    private let appGroupID = "group.com.canvas.browser"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - GenTab Sync

    /// Sync recent GenTabs to widget
    func syncRecentGenTabs(_ genTabs: [GenTab]) {
        let entries = genTabs.prefix(10).map { genTab -> WidgetGenTabEntry in
            WidgetGenTabEntry(
                id: genTab.id,
                title: genTab.title,
                icon: genTab.icon,
                preview: extractPreview(from: genTab),
                date: genTab.createdAt
            )
        }

        if let data = try? JSONEncoder().encode(entries) {
            sharedDefaults?.set(data, forKey: "widget_recent_gentabs")
            reloadWidgets()
        }
    }

    /// Add a single GenTab to the sync
    func addGenTab(_ genTab: GenTab) {
        var entries = getExistingGenTabs()

        // Remove if already exists (to move to front)
        entries.removeAll { $0.id == genTab.id }

        // Add to front
        let entry = WidgetGenTabEntry(
            id: genTab.id,
            title: genTab.title,
            icon: genTab.icon,
            preview: extractPreview(from: genTab),
            date: genTab.createdAt
        )
        entries.insert(entry, at: 0)

        // Keep only 10 most recent
        entries = Array(entries.prefix(10))

        if let data = try? JSONEncoder().encode(entries) {
            sharedDefaults?.set(data, forKey: "widget_recent_gentabs")
            reloadWidgets()
        }
    }

    /// Remove a GenTab from the sync
    func removeGenTab(_ genTab: GenTab) {
        var entries = getExistingGenTabs()
        entries.removeAll { $0.id == genTab.id }

        if let data = try? JSONEncoder().encode(entries) {
            sharedDefaults?.set(data, forKey: "widget_recent_gentabs")
            reloadWidgets()
        }
    }

    private func getExistingGenTabs() -> [WidgetGenTabEntry] {
        guard let data = sharedDefaults?.data(forKey: "widget_recent_gentabs"),
              let entries = try? JSONDecoder().decode([WidgetGenTabEntry].self, from: data) else {
            return []
        }
        return entries
    }

    private func extractPreview(from genTab: GenTab) -> String {
        for component in genTab.components {
            switch component {
            case .header(let text):
                return String(text.prefix(50))
            case .paragraph(let text):
                return String(text.prefix(50))
            case .cardGrid(let cards):
                return "\(cards.count) cards"
            case .map(let locations):
                return "\(locations.count) locations"
            case .bulletList(let items):
                return items.first ?? "List"
            case .numberedList(let items):
                return items.first ?? "List"
            case .keyValue(let pairs):
                return pairs.first?.key ?? "Details"
            case .callout(let type, _):
                return type.rawValue.capitalized
            default:
                continue
            }
        }
        return "GenTab"
    }

    // MARK: - Bookmark Sync

    /// Sync bookmarks to widget
    func syncBookmarks(_ bookmarks: [Bookmark]) {
        let entries = bookmarks.prefix(10).map { bookmark -> WidgetBookmarkEntry in
            WidgetBookmarkEntry(
                id: bookmark.id,
                title: bookmark.title,
                url: bookmark.url,
                favicon: bookmark.favicon
            )
        }

        if let data = try? JSONEncoder().encode(entries) {
            sharedDefaults?.set(data, forKey: "widget_bookmarks")
            reloadWidgets()
        }
    }

    /// Add a single bookmark to the sync
    func addBookmark(_ bookmark: Bookmark) {
        var entries = getExistingBookmarks()

        // Remove if already exists
        entries.removeAll { $0.id == bookmark.id }

        // Add to front
        let entry = WidgetBookmarkEntry(
            id: bookmark.id,
            title: bookmark.title,
            url: bookmark.url,
            favicon: bookmark.favicon
        )
        entries.insert(entry, at: 0)

        // Keep only 10 most recent
        entries = Array(entries.prefix(10))

        if let data = try? JSONEncoder().encode(entries) {
            sharedDefaults?.set(data, forKey: "widget_bookmarks")
            reloadWidgets()
        }
    }

    /// Remove a bookmark from the sync
    func removeBookmark(id: UUID) {
        var entries = getExistingBookmarks()
        entries.removeAll { $0.id == id }

        if let data = try? JSONEncoder().encode(entries) {
            sharedDefaults?.set(data, forKey: "widget_bookmarks")
            reloadWidgets()
        }
    }

    private func getExistingBookmarks() -> [WidgetBookmarkEntry] {
        guard let data = sharedDefaults?.data(forKey: "widget_bookmarks"),
              let entries = try? JSONDecoder().decode([WidgetBookmarkEntry].self, from: data) else {
            return []
        }
        return entries
    }

    // MARK: - Widget Reload

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Force reload all Canvas widgets
    func forceReloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "RecentGenTabsWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "BookmarksWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "QuickActionsWidget")
    }
}

// MARK: - Widget Entry Models

struct WidgetGenTabEntry: Codable, Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let preview: String
    let date: Date
}

struct WidgetBookmarkEntry: Codable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let favicon: String?
}
