import XCTest

// Copy of GenTab models for testing (SPM executables can't be imported directly)
enum TestGenTabContentType: String, Codable {
    case cardGrid
    case map
    case interactive3D
    case custom
}

struct TestGenTab: Identifiable, Codable {
    let id: UUID
    let title: String
    let icon: String
    let contentType: TestGenTabContentType
    var items: [TestCardItem]
    var locations: [TestLocationItem]
    var availableActions: [String]

    init(
        id: UUID = UUID(),
        title: String,
        icon: String,
        contentType: TestGenTabContentType,
        items: [TestCardItem] = [],
        locations: [TestLocationItem] = [],
        availableActions: [String] = []
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.contentType = contentType
        self.items = items
        self.locations = locations
        self.availableActions = availableActions
    }
}

struct TestCardItem: Identifiable, Codable {
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

struct TestLocationItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let latitude: Double
    let longitude: Double
    let icon: String

    init(id: UUID = UUID(), title: String, latitude: Double, longitude: Double, icon: String) {
        self.id = id
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.icon = icon
    }
}

final class GenTabTests: XCTestCase {

    // MARK: - GenTab Creation Tests

    func testGenTabCreation() {
        let genTab = TestGenTab(
            title: "Test Tab",
            icon: "star.fill",
            contentType: .cardGrid
        )

        XCTAssertEqual(genTab.title, "Test Tab")
        XCTAssertEqual(genTab.icon, "star.fill")
        XCTAssertEqual(genTab.contentType, .cardGrid)
        XCTAssertTrue(genTab.items.isEmpty)
        XCTAssertTrue(genTab.locations.isEmpty)
        XCTAssertTrue(genTab.availableActions.isEmpty)
    }

    func testGenTabWithItems() {
        let items = [
            TestCardItem(title: "Item 1", description: "Description 1", actionTitle: "Action 1"),
            TestCardItem(title: "Item 2", description: "Description 2", actionTitle: "Action 2")
        ]

        let genTab = TestGenTab(
            title: "Card Grid Tab",
            icon: "square.grid.2x2",
            contentType: .cardGrid,
            items: items,
            availableActions: ["Refresh", "Export"]
        )

        XCTAssertEqual(genTab.items.count, 2)
        XCTAssertEqual(genTab.items[0].title, "Item 1")
        XCTAssertEqual(genTab.items[1].description, "Description 2")
        XCTAssertEqual(genTab.availableActions.count, 2)
    }

    func testGenTabWithLocations() {
        let locations = [
            TestLocationItem(title: "San Francisco", latitude: 37.7749, longitude: -122.4194, icon: "mappin"),
            TestLocationItem(title: "New York", latitude: 40.7128, longitude: -74.0060, icon: "building.2")
        ]

        let genTab = TestGenTab(
            title: "Map Tab",
            icon: "map",
            contentType: .map,
            locations: locations
        )

        XCTAssertEqual(genTab.contentType, .map)
        XCTAssertEqual(genTab.locations.count, 2)
        XCTAssertEqual(genTab.locations[0].latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(genTab.locations[1].title, "New York")
    }

    // MARK: - Codable Tests

    func testGenTabEncodeDecode() throws {
        let originalTab = TestGenTab(
            title: "Encodable Tab",
            icon: "doc.text",
            contentType: .cardGrid,
            items: [
                TestCardItem(title: "Card", description: "A test card", actionTitle: "View")
            ],
            availableActions: ["Save", "Share"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalTab)

        let decoder = JSONDecoder()
        let decodedTab = try decoder.decode(TestGenTab.self, from: data)

        XCTAssertEqual(decodedTab.title, originalTab.title)
        XCTAssertEqual(decodedTab.icon, originalTab.icon)
        XCTAssertEqual(decodedTab.contentType, originalTab.contentType)
        XCTAssertEqual(decodedTab.items.count, originalTab.items.count)
        XCTAssertEqual(decodedTab.availableActions, originalTab.availableActions)
    }

    func testCardItemWithImageURL() throws {
        let imageURL = URL(string: "https://example.com/image.png")!
        let card = TestCardItem(
            title: "Image Card",
            description: "Has an image",
            imageURL: imageURL,
            actionTitle: "View Image"
        )

        XCTAssertNotNil(card.imageURL)
        XCTAssertEqual(card.imageURL?.absoluteString, "https://example.com/image.png")

        // Test encoding/decoding preserves URL
        let data = try JSONEncoder().encode(card)
        let decoded = try JSONDecoder().decode(TestCardItem.self, from: data)
        XCTAssertEqual(decoded.imageURL, imageURL)
    }

    func testContentTypeRawValues() {
        XCTAssertEqual(TestGenTabContentType.cardGrid.rawValue, "cardGrid")
        XCTAssertEqual(TestGenTabContentType.map.rawValue, "map")
        XCTAssertEqual(TestGenTabContentType.interactive3D.rawValue, "interactive3D")
        XCTAssertEqual(TestGenTabContentType.custom.rawValue, "custom")
    }

    // MARK: - Identifiable Tests

    func testUniqueIdentifiers() {
        let tab1 = TestGenTab(title: "Tab 1", icon: "1.circle", contentType: .cardGrid)
        let tab2 = TestGenTab(title: "Tab 2", icon: "2.circle", contentType: .cardGrid)

        XCTAssertNotEqual(tab1.id, tab2.id)

        let card1 = TestCardItem(title: "Card 1", description: "", actionTitle: "")
        let card2 = TestCardItem(title: "Card 2", description: "", actionTitle: "")

        XCTAssertNotEqual(card1.id, card2.id)
    }
}
