import Foundation
import Combine

/// Manages reading list items with persistence
class ReadingListManager: ObservableObject {
    static let shared = ReadingListManager()

    @Published var items: [ReadingListItem] = []

    private let storageKey = "canvas_reading_list"

    init() {
        loadItems()
    }

    // MARK: - Operations

    func addItem(url: String, title: String, excerpt: String? = nil) {
        // Don't add duplicates
        guard !items.contains(where: { $0.url == url }) else { return }

        let item = ReadingListItem(url: url, title: title, excerpt: excerpt)
        items.insert(item, at: 0)
        saveItems()
    }

    func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }

    func markAsRead(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isRead = true
            items[index].readAt = Date()
            saveItems()
        }
    }

    func markAsUnread(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isRead = false
            items[index].readAt = nil
            saveItems()
        }
    }

    func isInReadingList(url: String) -> Bool {
        items.contains { $0.url == url }
    }

    func toggleReadingList(url: String, title: String, excerpt: String? = nil) {
        if let existing = items.first(where: { $0.url == url }) {
            removeItem(id: existing.id)
        } else {
            addItem(url: url, title: title, excerpt: excerpt)
        }
    }

    var unreadItems: [ReadingListItem] {
        items.filter { !$0.isRead }
    }

    var readItems: [ReadingListItem] {
        items.filter { $0.isRead }
    }

    // MARK: - Persistence

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ReadingListItem].self, from: data) {
            items = decoded
        }
    }
}

// MARK: - Model

struct ReadingListItem: Identifiable, Codable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var excerpt: String?
    var isRead: Bool
    var readAt: Date?
    let addedAt: Date

    init(id: UUID = UUID(), url: String, title: String, excerpt: String? = nil) {
        self.id = id
        self.url = url
        self.title = title
        self.excerpt = excerpt
        self.isRead = false
        self.readAt = nil
        self.addedAt = Date()
    }

    // CloudKit sync initializer
    init(id: UUID, url: String, title: String, excerpt: String?, isRead: Bool, addedAt: Date, readAt: Date?) {
        self.id = id
        self.url = url
        self.title = title
        self.excerpt = excerpt
        self.isRead = isRead
        self.addedAt = addedAt
        self.readAt = readAt
    }
}
