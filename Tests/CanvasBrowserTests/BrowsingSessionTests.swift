import XCTest

// Copy of BrowsingSession models for testing
struct TestWebTab: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var title: String
    var lastActive: Date
    var savedState: Data?

    init(id: UUID = UUID(), url: URL, title: String = "New Tab", lastActive: Date = Date()) {
        self.id = id
        self.url = url
        self.title = title
        self.lastActive = lastActive
        self.savedState = nil
    }
}

enum TestTabItem: Identifiable, Equatable {
    case web(TestWebTab)
    case gen(TestGenTab)

    var id: UUID {
        switch self {
        case .web(let tab): return tab.id
        case .gen(let tab): return tab.id
        }
    }

    var title: String {
        switch self {
        case .web(let tab): return tab.title
        case .gen(let tab): return tab.title
        }
    }

    static func == (lhs: TestTabItem, rhs: TestTabItem) -> Bool {
        lhs.id == rhs.id
    }
}

class TestBrowsingSession {
    var activeTabs: [TestTabItem] = []
    var currentTabId: UUID?

    func addTab(url: URL) {
        let newTab = TestWebTab(url: url)
        activeTabs.append(.web(newTab))
        currentTabId = newTab.id
    }

    func addGenTab(_ genTab: TestGenTab) {
        activeTabs.append(.gen(genTab))
        currentTabId = genTab.id
    }

    func closeTab(id: UUID) {
        activeTabs.removeAll { $0.id == id }
        if currentTabId == id {
            currentTabId = activeTabs.last?.id
        }
    }

    var currentTab: TestTabItem? {
        activeTabs.first { $0.id == currentTabId }
    }
}

final class BrowsingSessionTests: XCTestCase {

    var session: TestBrowsingSession!

    override func setUp() {
        super.setUp()
        session = TestBrowsingSession()
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    // MARK: - Tab Management Tests

    func testAddWebTab() {
        let url = URL(string: "https://example.com")!
        session.addTab(url: url)

        XCTAssertEqual(session.activeTabs.count, 1)
        XCTAssertNotNil(session.currentTabId)

        if case .web(let webTab) = session.activeTabs.first {
            XCTAssertEqual(webTab.url, url)
            XCTAssertEqual(webTab.title, "New Tab")
        } else {
            XCTFail("Expected web tab")
        }
    }

    func testAddMultipleTabs() {
        session.addTab(url: URL(string: "https://google.com")!)
        session.addTab(url: URL(string: "https://apple.com")!)
        session.addTab(url: URL(string: "https://github.com")!)

        XCTAssertEqual(session.activeTabs.count, 3)

        // Current tab should be the last added
        if case .web(let currentTab) = session.currentTab {
            XCTAssertEqual(currentTab.url.absoluteString, "https://github.com")
        } else {
            XCTFail("Expected web tab")
        }
    }

    func testAddGenTab() {
        let genTab = TestGenTab(
            title: "Test GenTab",
            icon: "sparkles",
            contentType: .cardGrid
        )
        session.addGenTab(genTab)

        XCTAssertEqual(session.activeTabs.count, 1)
        XCTAssertEqual(session.currentTabId, genTab.id)

        if case .gen(let tab) = session.currentTab {
            XCTAssertEqual(tab.title, "Test GenTab")
        } else {
            XCTFail("Expected gen tab")
        }
    }

    func testMixedTabs() {
        session.addTab(url: URL(string: "https://example.com")!)
        session.addGenTab(TestGenTab(title: "GenTab", icon: "star", contentType: .cardGrid))
        session.addTab(url: URL(string: "https://test.com")!)

        XCTAssertEqual(session.activeTabs.count, 3)

        // Verify tab types
        if case .web = session.activeTabs[0] {} else { XCTFail("Expected web tab at index 0") }
        if case .gen = session.activeTabs[1] {} else { XCTFail("Expected gen tab at index 1") }
        if case .web = session.activeTabs[2] {} else { XCTFail("Expected web tab at index 2") }
    }

    func testCloseTab() {
        session.addTab(url: URL(string: "https://google.com")!)
        let secondTabId = session.currentTabId!
        session.addTab(url: URL(string: "https://apple.com")!)

        session.closeTab(id: secondTabId)

        XCTAssertEqual(session.activeTabs.count, 1)
        XCTAssertNotEqual(session.currentTabId, secondTabId)
    }

    func testCloseCurrentTab() {
        session.addTab(url: URL(string: "https://first.com")!)
        let firstId = session.currentTabId!
        session.addTab(url: URL(string: "https://second.com")!)
        let secondId = session.currentTabId!

        session.closeTab(id: secondId)

        // Should switch to previous tab
        XCTAssertEqual(session.currentTabId, firstId)
    }

    func testCloseAllTabs() {
        session.addTab(url: URL(string: "https://a.com")!)
        session.addTab(url: URL(string: "https://b.com")!)

        let ids = session.activeTabs.map { $0.id }
        for id in ids {
            session.closeTab(id: id)
        }

        XCTAssertTrue(session.activeTabs.isEmpty)
        XCTAssertNil(session.currentTabId)
        XCTAssertNil(session.currentTab)
    }

    func testEmptySession() {
        XCTAssertTrue(session.activeTabs.isEmpty)
        XCTAssertNil(session.currentTabId)
        XCTAssertNil(session.currentTab)
    }

    // MARK: - WebTab Tests

    func testWebTabInitialization() {
        let url = URL(string: "https://test.com/page")!
        let tab = TestWebTab(url: url)

        XCTAssertEqual(tab.url, url)
        XCTAssertEqual(tab.title, "New Tab")
        XCTAssertNil(tab.savedState)
        XCTAssertNotNil(tab.id)
    }

    func testWebTabEncodeDecode() throws {
        let url = URL(string: "https://encoded.com")!
        let originalTab = TestWebTab(url: url, title: "Encoded Tab")

        let data = try JSONEncoder().encode(originalTab)
        let decoded = try JSONDecoder().decode(TestWebTab.self, from: data)

        XCTAssertEqual(decoded.id, originalTab.id)
        XCTAssertEqual(decoded.url, originalTab.url)
        XCTAssertEqual(decoded.title, originalTab.title)
    }

    // MARK: - TabItem Tests

    func testTabItemTitle() {
        let webTab = TestWebTab(url: URL(string: "https://web.com")!, title: "Web Title")
        let genTab = TestGenTab(title: "Gen Title", icon: "star", contentType: .cardGrid)

        let webItem = TestTabItem.web(webTab)
        let genItem = TestTabItem.gen(genTab)

        XCTAssertEqual(webItem.title, "Web Title")
        XCTAssertEqual(genItem.title, "Gen Title")
    }

    func testTabItemId() {
        let webTab = TestWebTab(url: URL(string: "https://test.com")!)
        let genTab = TestGenTab(title: "Test", icon: "star", contentType: .cardGrid)

        let webItem = TestTabItem.web(webTab)
        let genItem = TestTabItem.gen(genTab)

        XCTAssertEqual(webItem.id, webTab.id)
        XCTAssertEqual(genItem.id, genTab.id)
    }
}
