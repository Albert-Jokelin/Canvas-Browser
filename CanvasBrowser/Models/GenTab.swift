import Foundation

enum GenTabContentType: String, Codable {
    case cardGrid
    case map
    case interactive3D
    case custom
    case dashboard
}

struct GenTab: Identifiable, Codable {
    let id = UUID()
    let title: String
    let icon: String // SF Symbol
    let contentType: GenTabContentType
    
    // Data for CardGrid
    var items: [CardItem] = []
    
    // Data for Map
    var locations: [LocationItem] = []
    
    // Dynamic Actions
    var availableActions: [String] = [] // e.g., ["Planting Calendar", "Regional Dates"]

    enum ContentType {
        case cardGrid
        case map
        case interactive3D
        case custom
    }
}

struct CardItem: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let imageURL: URL?
    let actionTitle: String
}

struct LocationItem: Identifiable, Codable {
    let id = UUID()
    let title: String
    let latitude: Double
    let longitude: Double
    let icon: String
}
