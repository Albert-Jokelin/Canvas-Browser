import Foundation

// MARK: - GenTab (Component-Based Architecture)

/// A GenTab is an AI-generated interactive mini-app composed of flexible components.
/// The AI decides which components to use at runtime based on the content.
struct GenTab: Identifiable, Codable {
    let id: UUID
    var title: String
    var icon: String // SF Symbol
    var components: [GenTabComponent]
    var sourceURLs: [SourceAttribution]
    let createdAt: Date

    init(id: UUID = UUID(), title: String, icon: String, components: [GenTabComponent] = [], sourceURLs: [SourceAttribution] = []) {
        self.id = id
        self.title = title
        self.icon = icon
        self.components = components
        self.sourceURLs = sourceURLs
        self.createdAt = Date()
    }

    // Legacy convenience initializer for backward compatibility
    init(title: String, icon: String, contentType: GenTabContentType, items: [CardItem] = [], locations: [LocationItem] = [], availableActions: [String] = []) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.createdAt = Date()
        self.sourceURLs = []

        // Convert legacy format to components
        var components: [GenTabComponent] = []

        switch contentType {
        case .cardGrid:
            if !items.isEmpty {
                let cards = items.map { item in
                    GenTabComponent.CardData(
                        title: item.title,
                        subtitle: nil,
                        description: item.description,
                        imageURL: item.imageURL?.absoluteString,
                        sourceURL: nil,
                        metadata: ["actionTitle": item.actionTitle]
                    )
                }
                components.append(.cardGrid(cards: cards))
            }
        case .map:
            if !locations.isEmpty {
                let locs = locations.map { loc in
                    GenTabComponent.LocationData(title: loc.title, latitude: loc.latitude, longitude: loc.longitude)
                }
                components.append(.map(locations: locs))
            }
        case .dashboard:
            components.append(.header(text: "Dashboard Overview"))
            if !items.isEmpty {
                let cards = items.map { item in
                    GenTabComponent.CardData(
                        title: item.title,
                        subtitle: nil,
                        description: item.description,
                        imageURL: item.imageURL?.absoluteString,
                        sourceURL: nil,
                        metadata: ["actionTitle": item.actionTitle]
                    )
                }
                components.append(.cardGrid(cards: cards))
            }
        default:
            components.append(.paragraph(text: "Content not available"))
        }

        // Add actions as links if present
        if !availableActions.isEmpty {
            components.append(.divider)
            for action in availableActions {
                components.append(.link(title: action, url: "#"))
            }
        }

        self.components = components
    }
}

// MARK: - Source Attribution

/// Links GenTab content back to its source URLs
struct SourceAttribution: Identifiable, Codable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let domain: String

    init(id: UUID = UUID(), url: String, title: String, domain: String) {
        self.id = id
        self.url = url
        self.title = title
        self.domain = domain
    }
}

// MARK: - GenTab Component System

/// Flexible component system - AI chooses what to include
enum GenTabComponent: Codable, Equatable {
    case header(text: String)
    case paragraph(text: String)
    case bulletList(items: [String])
    case numberedList(items: [String])
    case table(columns: [String], rows: [[String]])
    case cardGrid(cards: [CardData])
    case map(locations: [LocationData])
    case keyValue(pairs: [KeyValuePair])
    case callout(type: CalloutType, text: String)
    case divider
    case link(title: String, url: String)
    case image(url: String, caption: String?)

    // MARK: - Nested Types

    enum CalloutType: String, Codable {
        case info
        case warning
        case tip
        case price
        case success
        case error
    }

    struct CardData: Codable, Equatable, Identifiable {
        let id: UUID
        let title: String
        let subtitle: String?
        let description: String?
        let imageURL: String?
        let sourceURL: String?
        let metadata: [String: String]?

        init(id: UUID = UUID(), title: String, subtitle: String? = nil, description: String? = nil,
             imageURL: String? = nil, sourceURL: String? = nil, metadata: [String: String]? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.description = description
            self.imageURL = imageURL
            self.sourceURL = sourceURL
            self.metadata = metadata
        }

        private enum CodingKeys: String, CodingKey {
            case id, title, subtitle, description, imageURL, sourceURL, metadata
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            // Generate ID if not present in JSON (backwards compatibility)
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            self.title = try container.decode(String.self, forKey: .title)
            self.subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            self.description = try container.decodeIfPresent(String.self, forKey: .description)
            self.imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
            self.sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
            self.metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata)
        }
    }

    struct LocationData: Codable, Equatable {
        let title: String
        let latitude: Double
        let longitude: Double
    }

    struct KeyValuePair: Codable, Equatable {
        let key: String
        let value: String
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case text, items, columns, rows, cards, locations, pairs, calloutType, url, caption, title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "header":
            let text = try container.decode(String.self, forKey: .text)
            self = .header(text: text)
        case "paragraph":
            let text = try container.decode(String.self, forKey: .text)
            self = .paragraph(text: text)
        case "bulletList":
            let items = try container.decode([String].self, forKey: .items)
            self = .bulletList(items: items)
        case "numberedList":
            let items = try container.decode([String].self, forKey: .items)
            self = .numberedList(items: items)
        case "table":
            let columns = try container.decode([String].self, forKey: .columns)
            let rows = try container.decode([[String]].self, forKey: .rows)
            self = .table(columns: columns, rows: rows)
        case "cardGrid":
            let cards = try container.decode([CardData].self, forKey: .cards)
            self = .cardGrid(cards: cards)
        case "map":
            let locations = try container.decode([LocationData].self, forKey: .locations)
            self = .map(locations: locations)
        case "keyValue":
            let pairs = try container.decode([KeyValuePair].self, forKey: .pairs)
            self = .keyValue(pairs: pairs)
        case "callout":
            let calloutType = try container.decode(CalloutType.self, forKey: .calloutType)
            let text = try container.decode(String.self, forKey: .text)
            self = .callout(type: calloutType, text: text)
        case "divider":
            self = .divider
        case "link":
            let title = try container.decode(String.self, forKey: .title)
            let url = try container.decode(String.self, forKey: .url)
            self = .link(title: title, url: url)
        case "image":
            let url = try container.decode(String.self, forKey: .url)
            let caption = try container.decodeIfPresent(String.self, forKey: .caption)
            self = .image(url: url, caption: caption)
        default:
            self = .paragraph(text: "Unknown component type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .header(let text):
            try container.encode("header", forKey: .type)
            try container.encode(text, forKey: .text)
        case .paragraph(let text):
            try container.encode("paragraph", forKey: .type)
            try container.encode(text, forKey: .text)
        case .bulletList(let items):
            try container.encode("bulletList", forKey: .type)
            try container.encode(items, forKey: .items)
        case .numberedList(let items):
            try container.encode("numberedList", forKey: .type)
            try container.encode(items, forKey: .items)
        case .table(let columns, let rows):
            try container.encode("table", forKey: .type)
            try container.encode(columns, forKey: .columns)
            try container.encode(rows, forKey: .rows)
        case .cardGrid(let cards):
            try container.encode("cardGrid", forKey: .type)
            try container.encode(cards, forKey: .cards)
        case .map(let locations):
            try container.encode("map", forKey: .type)
            try container.encode(locations, forKey: .locations)
        case .keyValue(let pairs):
            try container.encode("keyValue", forKey: .type)
            try container.encode(pairs, forKey: .pairs)
        case .callout(let type, let text):
            try container.encode("callout", forKey: .type)
            try container.encode(type, forKey: .calloutType)
            try container.encode(text, forKey: .text)
        case .divider:
            try container.encode("divider", forKey: .type)
        case .link(let title, let url):
            try container.encode("link", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(url, forKey: .url)
        case .image(let url, let caption):
            try container.encode("image", forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(caption, forKey: .caption)
        }
    }
}

// MARK: - Legacy Types (for backward compatibility)

enum GenTabContentType: String, Codable {
    case cardGrid
    case map
    case interactive3D
    case custom
    case dashboard
}

struct CardItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let imageURL: URL?
    let actionTitle: String

    init(id: UUID = UUID(), title: String, description: String, imageURL: URL? = nil, actionTitle: String) {
        self.id = id
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.actionTitle = actionTitle
    }
}

struct LocationItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let latitude: Double
    let longitude: Double
    let icon: String

    init(id: UUID = UUID(), title: String, latitude: Double, longitude: Double, icon: String = "mappin") {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.icon = icon
    }
}
