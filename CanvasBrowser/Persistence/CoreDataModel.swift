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
        
        let historyEntry = NSEntityDescription()
        historyEntry.name = "HistoryEntry"
        historyEntry.managedObjectClassName = NSStringFromClass(HistoryEntry.self)
        historyEntry.properties = [historyURLAttribute, historyTitleAttribute, historyDateAttribute]
        
        let historyIDAttribute = NSAttributeDescription()
        historyIDAttribute.name = "id"
        historyIDAttribute.attributeType = .UUIDAttributeType
        
        let historyCountAttribute = NSAttributeDescription()
        historyCountAttribute.name = "visitCount"
        historyCountAttribute.attributeType = .integer64AttributeType
        historyCountAttribute.defaultValue = 1

        historyEntry.properties = [historyURLAttribute, historyTitleAttribute, historyDateAttribute, historyIDAttribute, historyCountAttribute]
        
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
