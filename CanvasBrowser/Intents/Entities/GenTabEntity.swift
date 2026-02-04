import AppIntents
import Foundation

/// Entity representing a GenTab for App Intents
struct GenTabEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "GenTab"

    static var defaultQuery = GenTabEntityQuery()

    var id: UUID
    var title: String
    var icon: String
    var componentCount: Int
    var createdAt: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(componentCount) components",
            image: .init(systemName: icon)
        )
    }

    init(id: UUID, title: String, icon: String, componentCount: Int, createdAt: Date) {
        self.id = id
        self.title = title
        self.icon = icon
        self.componentCount = componentCount
        self.createdAt = createdAt
    }

    init(from genTab: GenTab) {
        self.id = genTab.id
        self.title = genTab.title
        self.icon = genTab.icon
        self.componentCount = genTab.components.count
        self.createdAt = genTab.createdAt
    }
}

// MARK: - GenTab Entity Query

struct GenTabEntityQuery: EntityQuery {
    private let genTabsKey = "canvas_synced_gentabs"

    func entities(for identifiers: [UUID]) async throws -> [GenTabEntity] {
        await MainActor.run {
            loadSavedGenTabs()
                .filter { identifiers.contains($0.id) }
                .map { GenTabEntity(from: $0) }
        }
    }

    func suggestedEntities() async throws -> [GenTabEntity] {
        await MainActor.run {
            // Return most recent 10 GenTabs
            Array(loadSavedGenTabs().prefix(10))
                .map { GenTabEntity(from: $0) }
        }
    }

    func defaultResult() async -> GenTabEntity? {
        await MainActor.run {
            loadSavedGenTabs().first.map { GenTabEntity(from: $0) }
        }
    }

    private func loadSavedGenTabs() -> [GenTab] {
        guard let data = UserDefaults.standard.data(forKey: genTabsKey) else { return [] }
        return (try? JSONDecoder().decode([GenTab].self, from: data)) ?? []
    }
}

// MARK: - String-based Query

extension GenTabEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [GenTabEntity] {
        await MainActor.run {
            let lowercasedQuery = string.lowercased()

            return loadSavedGenTabs()
                .filter { $0.title.lowercased().contains(lowercasedQuery) }
                .map { GenTabEntity(from: $0) }
        }
    }
}

// MARK: - Enumerable Query

extension GenTabEntityQuery: EnumerableEntityQuery {
    func allEntities() async throws -> [GenTabEntity] {
        await MainActor.run {
            loadSavedGenTabs().map { GenTabEntity(from: $0) }
        }
    }
}

// MARK: - Open GenTab Intent

/// Opens a saved GenTab
struct OpenGenTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Open GenTab"
    static var description = IntentDescription("Open a saved GenTab in Canvas Browser")

    @Parameter(title: "GenTab")
    var genTab: GenTabEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open GenTab \(\.$genTab)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openGenTabFromIntent,
                object: nil,
                userInfo: ["genTabId": genTab.id.uuidString]
            )
        }

        return .result(value: "Opening GenTab: \(genTab.title)")
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Notification Name

extension Notification.Name {
    static let openGenTabFromIntent = Notification.Name("com.canvas.browser.intent.openGenTab")
}
