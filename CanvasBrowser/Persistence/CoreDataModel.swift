import CoreData

class CoreDataModel {
    static let shared = CoreDataModel()
    
    let model: NSManagedObjectModel
    
    init() {
        let model = NSManagedObjectModel()
        
        // 1. HistoryEntry Entity
        let historyURLAttribute = NSAttributeDescription()
        historyURLAttribute.name = "url"
        historyURLAttribute.attributeType = .stringAttributeType
        
        let historyTitleAttribute = NSAttributeDescription()
        historyTitleAttribute.name = "title"
        historyTitleAttribute.attributeType = .stringAttributeType
        
        let historyDateAttribute = NSAttributeDescription()
        historyDateAttribute.name = "visitDate"
        historyDateAttribute.attributeType = .dateAttributeType
        
        // Create the entity
        let historyEntry = NSEntityDescription()
        historyEntry.name = "HistoryEntry"
        historyEntry.managedObjectClassName = NSStringFromClass(HistoryEntry.self)
        
        // Define ID attribute
        let historyIDAttribute = NSAttributeDescription()
        historyIDAttribute.name = "id"
        historyIDAttribute.attributeType = .UUIDAttributeType
        historyIDAttribute.isOptional = false
        
        // Define visit count attribute
        let historyCountAttribute = NSAttributeDescription()
        historyCountAttribute.name = "visitCount"
        historyCountAttribute.attributeType = .integer64AttributeType
        historyCountAttribute.defaultValue = 1

        // Set all properties ONCE (removes duplicate assignment bug)
        historyEntry.properties = [
            historyIDAttribute,
            historyURLAttribute,
            historyTitleAttribute,
            historyDateAttribute,
            historyCountAttribute
        ]
        
        // Add uniqueness constraint on URL to prevent duplicates
        historyEntry.uniquenessConstraints = [
            [historyURLAttribute.name]
        ]
        
        // Add indexes for common queries (improves performance)
        let urlIndex = NSFetchIndexDescription(name: "urlIndex", elements: [
            NSFetchIndexElementDescription(property: historyURLAttribute, collationType: .binary)
        ])
        let dateIndex = NSFetchIndexDescription(name: "dateIndex", elements: [
            NSFetchIndexElementDescription(property: historyDateAttribute, collationType: .binary)
        ])
        historyEntry.indexes = [urlIndex, dateIndex]
        
        // Finalize Model
        model.entities = [historyEntry]
        self.model = model
    }
}

// Managed Object Subclass
@objc(HistoryEntry)
public class HistoryEntry: NSManagedObject {
    @NSManaged public var url: String?
    @NSManaged public var title: String?
    @NSManaged public var visitDate: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var visitCount: Int64
}
