import Foundation
import CoreData

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var historyEntries: [HistoryEntry] = []
    
    private let context = PersistenceController.shared.container.viewContext
    
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
        
        try? context.save()
    }

    func addVisit(url: String, title: String){
        // return []
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
