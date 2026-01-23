import XCTest

// Copy of SemanticIntent models for testing
struct TestSemanticIntent: Codable, Identifiable {
    let id: UUID
    let intentDetected: Bool
    let intentType: String?
    let title: String
    let description: String
    let icon: String
    let suggestedActions: [TestAIAction]

    var shortDescription: String {
        String(title.prefix(20))
    }

    init(
        id: UUID = UUID(),
        intentDetected: Bool,
        intentType: String?,
        title: String,
        description: String,
        icon: String,
        suggestedActions: [TestAIAction] = []
    ) {
        self.id = id
        self.intentDetected = intentDetected
        self.intentType = intentType
        self.title = title
        self.description = description
        self.icon = icon
        self.suggestedActions = suggestedActions
    }
}

struct TestAIAction: Codable, Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let icon: String
    let actionType: String

    init(id: UUID = UUID(), title: String, subtitle: String, icon: String, actionType: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.actionType = actionType
    }
}

final class SemanticIntentTests: XCTestCase {

    // MARK: - Intent Creation Tests

    func testIntentCreation() {
        let intent = TestSemanticIntent(
            intentDetected: true,
            intentType: "research",
            title: "Research Intent",
            description: "User appears to be researching a topic",
            icon: "magnifyingglass"
        )

        XCTAssertTrue(intent.intentDetected)
        XCTAssertEqual(intent.intentType, "research")
        XCTAssertEqual(intent.title, "Research Intent")
        XCTAssertEqual(intent.icon, "magnifyingglass")
    }

    func testIntentWithNoType() {
        let intent = TestSemanticIntent(
            intentDetected: false,
            intentType: nil,
            title: "Unknown",
            description: "No intent detected",
            icon: "questionmark"
        )

        XCTAssertFalse(intent.intentDetected)
        XCTAssertNil(intent.intentType)
    }

    func testIntentWithActions() {
        let actions = [
            TestAIAction(
                title: "Create Summary",
                subtitle: "Summarize the current page",
                icon: "doc.text",
                actionType: "summarize"
            ),
            TestAIAction(
                title: "Save for Later",
                subtitle: "Add to reading list",
                icon: "bookmark",
                actionType: "bookmark"
            )
        ]

        let intent = TestSemanticIntent(
            intentDetected: true,
            intentType: "reading",
            title: "Reading Session",
            description: "Deep reading detected",
            icon: "book",
            suggestedActions: actions
        )

        XCTAssertEqual(intent.suggestedActions.count, 2)
        XCTAssertEqual(intent.suggestedActions[0].title, "Create Summary")
        XCTAssertEqual(intent.suggestedActions[1].actionType, "bookmark")
    }

    // MARK: - Short Description Tests

    func testShortDescriptionTruncation() {
        let intent = TestSemanticIntent(
            intentDetected: true,
            intentType: "shopping",
            title: "Product Comparison Shopping Session",
            description: "User is comparing products",
            icon: "cart"
        )

        XCTAssertEqual(intent.shortDescription, "Product Comparison S")
        XCTAssertEqual(intent.shortDescription.count, 20)
    }

    func testShortDescriptionNoTruncation() {
        let intent = TestSemanticIntent(
            intentDetected: true,
            intentType: "quick",
            title: "Quick Search",
            description: "Brief search",
            icon: "magnifyingglass"
        )

        XCTAssertEqual(intent.shortDescription, "Quick Search")
        XCTAssertLessThanOrEqual(intent.shortDescription.count, 20)
    }

    func testShortDescriptionEmpty() {
        let intent = TestSemanticIntent(
            intentDetected: false,
            intentType: nil,
            title: "",
            description: "",
            icon: "circle"
        )

        XCTAssertEqual(intent.shortDescription, "")
    }

    // MARK: - AIAction Tests

    func testAIActionCreation() {
        let action = TestAIAction(
            title: "Generate GenTab",
            subtitle: "Create interactive visualization",
            icon: "sparkles",
            actionType: "gentab"
        )

        XCTAssertEqual(action.title, "Generate GenTab")
        XCTAssertEqual(action.subtitle, "Create interactive visualization")
        XCTAssertEqual(action.icon, "sparkles")
        XCTAssertEqual(action.actionType, "gentab")
    }

    func testAIActionIdentifiable() {
        let action1 = TestAIAction(title: "A", subtitle: "", icon: "", actionType: "")
        let action2 = TestAIAction(title: "B", subtitle: "", icon: "", actionType: "")

        XCTAssertNotEqual(action1.id, action2.id)
    }

    // MARK: - Codable Tests

    func testIntentEncodeDecode() throws {
        let actions = [
            TestAIAction(title: "Action 1", subtitle: "Sub 1", icon: "star", actionType: "type1")
        ]

        let originalIntent = TestSemanticIntent(
            intentDetected: true,
            intentType: "test",
            title: "Test Intent",
            description: "For testing",
            icon: "checkmark",
            suggestedActions: actions
        )

        let data = try JSONEncoder().encode(originalIntent)
        let decoded = try JSONDecoder().decode(TestSemanticIntent.self, from: data)

        XCTAssertEqual(decoded.id, originalIntent.id)
        XCTAssertEqual(decoded.intentDetected, originalIntent.intentDetected)
        XCTAssertEqual(decoded.intentType, originalIntent.intentType)
        XCTAssertEqual(decoded.title, originalIntent.title)
        XCTAssertEqual(decoded.description, originalIntent.description)
        XCTAssertEqual(decoded.icon, originalIntent.icon)
        XCTAssertEqual(decoded.suggestedActions.count, 1)
    }

    func testActionEncodeDecode() throws {
        let original = TestAIAction(
            title: "Encode Test",
            subtitle: "Testing encoding",
            icon: "doc",
            actionType: "test"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TestAIAction.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.subtitle, original.subtitle)
        XCTAssertEqual(decoded.icon, original.icon)
        XCTAssertEqual(decoded.actionType, original.actionType)
    }

    // MARK: - Intent Types Tests

    func testCommonIntentTypes() {
        let intentTypes = ["research", "shopping", "reading", "coding", "entertainment", "travel", "learning"]

        for type in intentTypes {
            let intent = TestSemanticIntent(
                intentDetected: true,
                intentType: type,
                title: "\(type.capitalized) Intent",
                description: "A \(type) session",
                icon: "circle"
            )
            XCTAssertEqual(intent.intentType, type)
        }
    }
}
