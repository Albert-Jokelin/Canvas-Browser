import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var sessionManager: BrowsingSession
    @Published var aiOrchestrator: AIOrchestrator
    @Published var tabGroupManager: TabGroupManager

    /// Whether the tab groups sidebar is visible
    @Published var showTabGroupsSidebar: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var genTabObserver: NSObjectProtocol?

    // We'll init the services here
    init() {
        let historyManager = HistoryManager.shared
        // Placeholder for GeminiService, using a basic init for now until Phase 2
        let geminiService = GeminiService()

        self.sessionManager = BrowsingSession()
        self.aiOrchestrator = AIOrchestrator(geminiService: geminiService, historyManager: historyManager)
        self.tabGroupManager = TabGroupManager()

        // Wire up session manager for content extraction
        self.aiOrchestrator.sessionManager = self.sessionManager

        // Propagate session changes to AppState consumers
        sessionManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Clean up tab groups when tabs are closed
        sessionManager.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let existingIds = Set(self.sessionManager.activeTabs.map { $0.id })
                self.tabGroupManager.cleanupGroups(existingTabIds: existingIds)
            }
            .store(in: &cancellables)

        genTabObserver = NotificationCenter.default.addObserver(forName: .triggerDemoGenTab, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.createGenTabFromSelection()
            }
        }
    }

    deinit {
        // Clean up notification observer
        if let observer = genTabObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cancellables.removeAll()
    }
    
    /// Create a GenTab from the current browsing context using AI
    func createGenTabFromSelection() {
        Task {
            // Extract content from open tabs
            let contents = await aiOrchestrator.extractOpenTabContents()

            if contents.isEmpty {
                // No tabs to analyze - create a simple welcome GenTab
                let welcomeTab = GenTab(
                    title: "Welcome to GenTabs",
                    icon: "sparkles",
                    components: [
                        .header(text: "AI-Powered Browsing"),
                        .paragraph(text: "GenTabs are dynamic, interactive mini-apps created by AI based on your browsing context."),
                        .callout(type: .tip, text: "Open some tabs and try again to generate a GenTab from your browsing session."),
                        .divider,
                        .header(text: "How It Works"),
                        .numberedList(items: [
                            "Open multiple related tabs (shopping, travel, recipes, etc.)",
                            "Press Cmd+Shift+G or wait for automatic suggestions",
                            "AI analyzes your tabs and creates an interactive summary"
                        ])
                    ],
                    sourceURLs: []
                )
                sessionManager.addGenTab(welcomeTab)
                return
            }

            // Build context from tab contents
            let contextParts = contents.map { content in
                "[\(content.domain)] \(content.title): \(String(content.textContent.prefix(500)))"
            }
            let context = contextParts.joined(separator: "\n\n")

            let prompt = """
            Create a helpful GenTab summarizing this browsing context:

            \(context)
            """

            // Create source attributions
            let sourceAttrs = contents.map { content in
                SourceAttribution(url: content.url, title: content.title, domain: content.domain)
            }

            do {
                let genTab = try await aiOrchestrator.geminiService.buildGenTab(for: prompt, sourceURLs: sourceAttrs)
                sessionManager.addGenTab(genTab)
            } catch {
                print("Failed to create GenTab: \(error)")
                // Create error GenTab
                let errorTab = GenTab(
                    title: "GenTab Error",
                    icon: "exclamationmark.triangle",
                    components: [
                        .header(text: "Couldn't Create GenTab"),
                        .paragraph(text: "There was an error generating content from your tabs."),
                        .callout(type: .warning, text: error.localizedDescription),
                        .divider,
                        .paragraph(text: "Make sure you have a valid Gemini API key configured in Settings.")
                    ],
                    sourceURLs: []
                )
                sessionManager.addGenTab(errorTab)
            }
        }
    }
}
