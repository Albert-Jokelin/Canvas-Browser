import Foundation

struct SemanticIntent: Codable, Identifiable {
    let id = UUID()
    let intentDetected: Bool
    let intentType: String?
    let title: String
    let menuBarTitle: String
    let description: String
    let icon: String
    let confidence: Double
    let sourceURLs: [String]
    let suggestedActions: [AIAction]
    let createdAt: Date
    
    var shortDescription: String {
        String(title.prefix(20))
    }
    
    enum CodingKeys: String, CodingKey {
        case intentDetected, intentType, title, menuBarTitle, description
        case icon, confidence, sourceURLs, suggestedActions, createdAt
    }
}

struct AIAction: Codable, Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let actionType: String
    
    enum CodingKeys: String, CodingKey {
        case title, subtitle, icon, actionType
    }
}