import AppIntents
import Foundation

/// Entity representing a bookmark for App Intents
struct BookmarkEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bookmark"

    static var defaultQuery = BookmarkEntityQuery()

    var id: UUID
    var title: String
    var url: String
    var folderName: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: url.contains("://") ? LocalizedStringResource(stringLiteral: URL(string: url)?.host ?? url) : LocalizedStringResource(stringLiteral: url),
            image: .init(systemName: "bookmark.fill")
        )
    }

    init(id: UUID, title: String, url: String, folderName: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.folderName = folderName
    }

    init(from bookmark: Bookmark) {
        self.id = bookmark.id
        self.title = bookmark.title
        self.url = bookmark.url
        self.folderName = nil // Could be resolved from BookmarkManager
    }
}

// MARK: - Bookmark Entity Query

struct BookmarkEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [BookmarkEntity] {
        await MainActor.run {
            BookmarkManager.shared.bookmarks
                .filter { identifiers.contains($0.id) }
                .map { BookmarkEntity(from: $0) }
        }
    }

    func suggestedEntities() async throws -> [BookmarkEntity] {
        await MainActor.run {
            // Return most recent 10 bookmarks
            Array(BookmarkManager.shared.bookmarks.prefix(10))
                .map { BookmarkEntity(from: $0) }
        }
    }

    func defaultResult() async -> BookmarkEntity? {
        await MainActor.run {
            BookmarkManager.shared.bookmarks.first.map { BookmarkEntity(from: $0) }
        }
    }
}

// MARK: - String-based Query

extension BookmarkEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [BookmarkEntity] {
        await MainActor.run {
            let lowercasedQuery = string.lowercased()

            return BookmarkManager.shared.bookmarks
                .filter {
                    $0.title.lowercased().contains(lowercasedQuery) ||
                    $0.url.lowercased().contains(lowercasedQuery)
                }
                .map { BookmarkEntity(from: $0) }
        }
    }
}

// MARK: - Property Query

extension BookmarkEntityQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [BookmarkEntity] {
        await MainActor.run {
            BookmarkManager.shared.bookmarks.map { BookmarkEntity(from: $0) }
        }
    }
}
