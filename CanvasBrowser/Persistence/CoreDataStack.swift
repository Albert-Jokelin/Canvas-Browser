import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = CoreDataModel.shared.model
        container = NSPersistentContainer(name: "CanvasModel", managedObjectModel: model)

        // Configure automatic migration
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("Core Data failed to load: \(error), \(error.userInfo)")

                // Attempt recovery by deleting and recreating the store
                if let storeURL = storeDescription.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        print("Removed corrupted store, will recreate on next launch")
                    } catch {
                        print("Failed to remove corrupted store: \(error)")
                    }
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
