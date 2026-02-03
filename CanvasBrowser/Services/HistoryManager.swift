import Foundation
import CoreData
import OSLog

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()

    @Published var historyEntries: [HistoryEntry] = []

    private let context: NSManagedObjectContext

    /// Standard initializer using shared persistence controller
    private init() {
        self.context = PersistenceController.shared.container.viewContext
    }

    /// Injectable initializer for testing
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // struct HistoryEntry: Identifiable {
    //     let id: UUID
    //     let url: String
    //     let title: String
    //     let visitDate: Date
    //     var visitCount: Int
    // }
    
    // MARK: - Get Recent History
    
    func getRecentHistory(limit: Int) -> [HistoryItem] {
        let request = HistoryEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \HistoryEntry.visitDate, ascending: false)]
        request.fetchLimit = limit

        do {
            let results = try context.fetch(request) as? [HistoryEntry] ?? []
            return results.map { entry in
                HistoryItem(
                    url: entry.url ?? "",
                    title: entry.title ?? "Untitled",
                    visitDate: entry.visitDate ?? Date()
                )
            }
        } catch {
            print("Failed to fetch history: \(error)")
            return []
        }
    }

    /// Alias for getRecentHistory for convenience
    func recentHistory(limit: Int) -> [HistoryItem] {
        getRecentHistory(limit: limit)
    }
    
    func addEntry(url: String, title: String) {
        let entry: HistoryEntry = HistoryEntry(context: context)
        entry.id = UUID()
        entry.url = url
        entry.title = title
        entry.visitDate = Date()
        entry.visitCount = 1

        do {
            try context.save()
        } catch {
            print("Failed to save history entry: \(error.localizedDescription)")
        }
    }

    /// Record a visit to a URL, updating existing entry or creating new one
    func addVisit(url: String, title: String) {
        // Skip empty or about: URLs
        guard !url.isEmpty, !url.hasPrefix("about:") else { return }

        // Use background context to avoid blocking main thread
        let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
        backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        backgroundContext.perform {
            let request = HistoryEntry.fetchRequest()
            request.predicate = NSPredicate(format: "url == %@", url)
            request.fetchLimit = 1

            do {
                let results = try backgroundContext.fetch(request) as? [HistoryEntry] ?? []

                if let existing = results.first {
                    // Update existing entry
                    existing.visitCount += 1
                    existing.visitDate = Date()
                    if !title.isEmpty {
                        existing.title = title
                    }
                    Logger.persistence.debug("Updated history entry: \(url)")
                } else {
                    // Create new entry
                    let entry = HistoryEntry(context: backgroundContext)
                    entry.id = UUID()
                    entry.url = url
                    entry.title = title.isEmpty ? "Untitled" : title
                    entry.visitDate = Date()
                    entry.visitCount = 1
                    Logger.persistence.debug("Created history entry: \(url)")
                }

                if backgroundContext.hasChanges {
                    try backgroundContext.save()
                }
            } catch {
                Logger.persistence.error("Failed to add history visit: \(error.localizedDescription)")
                CrashReporter.shared.recordError(error, context: ["url": url])
                backgroundContext.rollback()
            }
        }
    }
}

// MARK: - History Item Model

struct HistoryItem: Identifiable {
    let id: UUID = UUID()
    let url: URL?
    let title: String?
    let visitDate: Date

    init(url: String, title: String, visitDate: Date) {
        self.url = URL(string: url)
        self.title = title
        self.visitDate = visitDate
    }
}
