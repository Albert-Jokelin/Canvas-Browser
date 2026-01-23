import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = CoreDataModel.shared.model
        container = NSPersistentContainer(name: "CanvasModel", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data failed to load: \(error)")
                // For a real app, handle migration or reset here
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
