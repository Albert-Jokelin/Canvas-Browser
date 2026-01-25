import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Manages Spotlight indexing for Canvas Browser content
class SpotlightIndexManager {
    static let shared = SpotlightIndexManager()

    // Domain identifiers for different content types
    private let genTabDomain = "com.canvas.gentabs"
    private let bookmarkDomain = "com.canvas.bookmarks"
    private let historyDomain = "com.canvas.history"

    private let searchableIndex = CSSearchableIndex.default()

    private init() {}

    // MARK: - GenTab Indexing

    /// Index a GenTab for Spotlight search
    func indexGenTab(_ genTab: GenTab) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = genTab.title
        attributeSet.contentDescription = buildGenTabDescription(genTab)
        attributeSet.keywords = extractKeywords(from: genTab)
        attributeSet.creator = "Canvas Browser"
        attributeSet.contentCreationDate = Date()
        attributeSet.contentModificationDate = Date()

        // Add thumbnail if available
        if let iconName = genTab.icon.data(using: .utf8) {
            attributeSet.thumbnailData = iconName
        }

        let item = CSSearchableItem(
            uniqueIdentifier: genTab.id.uuidString,
            domainIdentifier: genTabDomain,
            attributeSet: attributeSet
        )

        // Set expiration date (30 days from now)
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index GenTab: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a GenTab from Spotlight index
    func removeGenTab(_ genTab: GenTab) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [genTab.id.uuidString]) { error in
            if let error = error {
                print("Failed to remove GenTab from index: \(error.localizedDescription)")
            }
        }
    }

    /// Index multiple GenTabs
    func indexGenTabs(_ genTabs: [GenTab]) {
        let items = genTabs.map { genTab -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
            attributeSet.title = genTab.title
            attributeSet.contentDescription = buildGenTabDescription(genTab)
            attributeSet.keywords = extractKeywords(from: genTab)
            attributeSet.creator = "Canvas Browser"
            attributeSet.contentCreationDate = Date()

            let item = CSSearchableItem(
                uniqueIdentifier: genTab.id.uuidString,
                domainIdentifier: genTabDomain,
                attributeSet: attributeSet
            )
            item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            return item
        }

        searchableIndex.indexSearchableItems(items) { error in
            if let error = error {
                print("Failed to index GenTabs: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Bookmark Indexing

    /// Index a bookmark for Spotlight search
    func indexBookmark(url: String, title: String, id: UUID) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .url)
        attributeSet.title = title
        attributeSet.url = URL(string: url)
        attributeSet.contentDescription = "Bookmark: \(url)"
        attributeSet.creator = "Canvas Browser"
        attributeSet.contentCreationDate = Date()

        // Extract domain as keyword
        if let urlObj = URL(string: url), let host = urlObj.host {
            attributeSet.keywords = [host, title]
        }

        let item = CSSearchableItem(
            uniqueIdentifier: id.uuidString,
            domainIdentifier: bookmarkDomain,
            attributeSet: attributeSet
        )

        item.expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())

        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index bookmark: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a bookmark from Spotlight index
    func removeBookmark(id: UUID) {
        searchableIndex.deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            if let error = error {
                print("Failed to remove bookmark from index: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - History Indexing

    /// Index a history entry for Spotlight search
    func indexHistoryEntry(url: String, title: String, id: UUID, visitDate: Date) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .url)
        attributeSet.title = title
        attributeSet.url = URL(string: url)
        attributeSet.contentDescription = "Visited: \(url)"
        attributeSet.creator = "Canvas Browser"
        attributeSet.contentCreationDate = visitDate
        attributeSet.lastUsedDate = visitDate

        if let urlObj = URL(string: url), let host = urlObj.host {
            attributeSet.keywords = [host, title]
        }

        let item = CSSearchableItem(
            uniqueIdentifier: id.uuidString,
            domainIdentifier: historyDomain,
            attributeSet: attributeSet
        )

        // History items expire after 7 days
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())

        searchableIndex.indexSearchableItems([item]) { error in
            if let error = error {
                print("Failed to index history entry: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Bulk Operations

    /// Clear all Canvas Browser content from Spotlight
    func clearAllIndexes() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [
            genTabDomain,
            bookmarkDomain,
            historyDomain
        ]) { error in
            if let error = error {
                print("Failed to clear Spotlight indexes: \(error.localizedDescription)")
            }
        }
    }

    /// Clear only GenTabs from Spotlight
    func clearGenTabIndex() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [genTabDomain]) { error in
            if let error = error {
                print("Failed to clear GenTab index: \(error.localizedDescription)")
            }
        }
    }

    /// Clear only bookmarks from Spotlight
    func clearBookmarkIndex() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [bookmarkDomain]) { error in
            if let error = error {
                print("Failed to clear bookmark index: \(error.localizedDescription)")
            }
        }
    }

    /// Clear only history from Spotlight
    func clearHistoryIndex() {
        searchableIndex.deleteSearchableItems(withDomainIdentifiers: [historyDomain]) { error in
            if let error = error {
                print("Failed to clear history index: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func buildGenTabDescription(_ genTab: GenTab) -> String {
        var parts: [String] = []

        // Add component descriptions
        for component in genTab.components {
            switch component {
            case .header(let text):
                parts.append(String(text.prefix(100)))
            case .paragraph(let text):
                parts.append(String(text.prefix(100)))
            case .cardGrid(let cards):
                parts.append("Cards: \(cards.map { $0.title }.joined(separator: ", "))")
            case .map:
                parts.append("Map view")
            case .link(let title, _):
                parts.append("Link: \(title)")
            case .image(_, let caption):
                if let caption = caption {
                    parts.append("Image: \(caption)")
                }
            case .bulletList(let items):
                parts.append("List: \(items.prefix(3).joined(separator: ", "))")
            case .numberedList(let items):
                parts.append("List: \(items.prefix(3).joined(separator: ", "))")
            case .divider:
                break
            case .table(let columns, _):
                parts.append("Table: \(columns.joined(separator: ", "))")
            case .keyValue(let pairs):
                parts.append("Details: \(pairs.prefix(3).map { $0.key }.joined(separator: ", "))")
            case .callout(let type, let text):
                parts.append("\(type.rawValue.capitalized): \(String(text.prefix(50)))")
            }
        }

        return parts.joined(separator: " | ")
    }

    private func extractKeywords(from genTab: GenTab) -> [String] {
        var keywords: [String] = [genTab.title]

        // Extract keywords from components
        for component in genTab.components {
            switch component {
            case .cardGrid(let cards):
                keywords.append(contentsOf: cards.map { $0.title })
            case .link(let title, _):
                keywords.append(title)
            case .bulletList(let items):
                keywords.append(contentsOf: items.prefix(5))
            case .numberedList(let items):
                keywords.append(contentsOf: items.prefix(5))
            case .keyValue(let pairs):
                keywords.append(contentsOf: pairs.map { $0.key })
            default:
                break
            }
        }

        return keywords
    }

    // MARK: - Handle Spotlight Continuation

    /// Handle when user taps on a Spotlight result
    /// Returns the identifier to open (GenTab ID, bookmark URL, etc.)
    func handleSpotlightActivity(_ userActivity: NSUserActivity) -> String? {
        guard userActivity.activityType == CSSearchableItemActionType,
              let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return nil
        }
        return identifier
    }
}

// MARK: - Integration with BookmarkManager

extension BookmarkManager {
    /// Index a newly added bookmark
    func indexBookmarkInSpotlight(_ bookmark: Bookmark) {
        SpotlightIndexManager.shared.indexBookmark(
            url: bookmark.url,
            title: bookmark.title,
            id: bookmark.id
        )
    }

    /// Remove a bookmark from Spotlight when deleted
    func removeBookmarkFromSpotlight(_ bookmark: Bookmark) {
        SpotlightIndexManager.shared.removeBookmark(id: bookmark.id)
    }
}

// MARK: - Integration with BrowsingSession

extension BrowsingSession {
    /// Index a GenTab when it's added to the session
    func indexGenTabInSpotlight(_ genTab: GenTab) {
        SpotlightIndexManager.shared.indexGenTab(genTab)
    }

    /// Remove a GenTab from Spotlight when closed
    func removeGenTabFromSpotlight(_ genTab: GenTab) {
        SpotlightIndexManager.shared.removeGenTab(genTab)
    }
}
