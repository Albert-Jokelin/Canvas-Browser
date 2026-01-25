import Foundation
import Combine

/// Manages bookmarks with persistence to UserDefaults
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()

    @Published var bookmarks: [Bookmark] = []
    @Published var folders: [BookmarkFolder] = []

    private let bookmarksKey = "canvas_bookmarks"
    private let foldersKey = "canvas_bookmark_folders"

    init() {
        loadBookmarks()
        loadFolders()
    }

    // MARK: - Bookmark Operations

    func addBookmark(url: String, title: String, folderId: UUID? = nil) {
        let bookmark = Bookmark(url: url, title: title, folderId: folderId)
        bookmarks.insert(bookmark, at: 0)
        saveBookmarks()

        // Index in Spotlight
        SpotlightIndexManager.shared.indexBookmark(url: url, title: title, id: bookmark.id)

        // Sync to widgets
        WidgetDataSync.shared.addBookmark(bookmark)
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()

        // Remove from Spotlight
        SpotlightIndexManager.shared.removeBookmark(id: id)

        // Sync to widgets
        WidgetDataSync.shared.removeBookmark(id: id)
    }

    func updateBookmark(_ bookmark: Bookmark) {
        if let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
            bookmarks[index] = bookmark
            saveBookmarks()
        }
    }

    func isBookmarked(url: String) -> Bool {
        bookmarks.contains { $0.url == url }
    }

    func toggleBookmark(url: String, title: String) {
        if let existing = bookmarks.first(where: { $0.url == url }) {
            removeBookmark(id: existing.id)
        } else {
            addBookmark(url: url, title: title)
        }
    }

    // MARK: - Folder Operations

    func createFolder(name: String, parentId: UUID? = nil) {
        let folder = BookmarkFolder(name: name, parentId: parentId)
        folders.append(folder)
        saveFolders()
    }

    func removeFolder(id: UUID) {
        // Move bookmarks out of folder
        for i in bookmarks.indices {
            if bookmarks[i].folderId == id {
                bookmarks[i].folderId = nil
            }
        }
        folders.removeAll { $0.id == id }
        saveFolders()
        saveBookmarks()
    }

    func bookmarksInFolder(_ folderId: UUID?) -> [Bookmark] {
        bookmarks.filter { $0.folderId == folderId }
    }

    // MARK: - Persistence

    private func saveBookmarks() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        }
    }

    private func loadBookmarks() {
        if let data = UserDefaults.standard.data(forKey: bookmarksKey),
           let decoded = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = decoded
        }
    }

    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: foldersKey)
        }
    }

    private func loadFolders() {
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([BookmarkFolder].self, from: data) {
            folders = decoded
        }
    }
}

// MARK: - Models

struct Bookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var folderId: UUID?
    var favicon: String? // Base64 encoded
    let createdAt: Date

    init(id: UUID = UUID(), url: String, title: String, folderId: UUID? = nil, favicon: String? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.folderId = folderId
        self.favicon = favicon
        self.createdAt = Date()
    }
}

struct BookmarkFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var parentId: UUID?
    let createdAt: Date

    init(id: UUID = UUID(), name: String, parentId: UUID? = nil) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.createdAt = Date()
    }
}
