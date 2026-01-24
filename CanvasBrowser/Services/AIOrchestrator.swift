import Foundation
import SwiftUI
import Combine

class AIOrchestrator: ObservableObject {
    @Published var currentIntent: SemanticIntent?
    @Published var suggestedActions: [AIAction] = []
    @Published var recentGenTabs: [GenTab] = []

    /// Pending GenTab suggestion from intent detection
    @Published var pendingSuggestion: IntentClassifier.Analysis?

    /// Whether suggestion banner should be shown
    @Published var showSuggestionBanner: Bool = false

    let geminiService: GeminiService
    private let historyManager: HistoryManager
    let contentExtractor: ContentExtractor
    private let intentClassifier: IntentClassifier
    private var intentTimer: Timer?

    /// Tracks dismissed suggestions to avoid re-showing
    private var dismissedSuggestionHashes: Set<String> = []

    /// Reference to the browsing session for tab access (set by AppState)
    weak var sessionManager: BrowsingSession?

    init(geminiService: GeminiService, historyManager: HistoryManager, contentExtractor: ContentExtractor = .shared) {
        self.geminiService = geminiService
        self.historyManager = historyManager
        self.contentExtractor = contentExtractor
        self.intentClassifier = IntentClassifier()

        startIntentDetection()
    }

    // MARK: - Intent Detection

    func startIntentDetection() {
        // Monitor browsing patterns every 30 seconds
        intentTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.analyzeRecentBrowsing()
            }
        }
    }

    func stopIntentDetection() {
        intentTimer?.invalidate()
        intentTimer = nil
    }

    // MARK: - Handle User Messages

    func handleUserMessage(_ message: String) async -> String {
        // Priority: Check if this should create a GenTab before standard text generation
        let shouldCreate = await geminiService.shouldCreateGenTab(for: message)

        if shouldCreate {
            do {
                // Get source attributions from open tabs
                let contents = await extractOpenTabContents()
                let sourceAttrs = contents.map { content in
                    SourceAttribution(url: content.url, title: content.title, domain: content.domain)
                }

                let genTab = try await geminiService.buildGenTab(for: message, sourceURLs: sourceAttrs)

                await MainActor.run {
                    self.recentGenTabs.append(genTab)
                    self.sessionManager?.addGenTab(genTab)
                }

                // Notify UI to show GenTab
                NotificationCenter.default.post(
                    name: NSNotification.Name("genTabCreated"),
                    object: nil,
                    userInfo: ["genTab": genTab]
                )

                return "I've created a \(genTab.title) GenTab for you!"
            } catch {
                return "I'd like to create an app for that, but encountered an error: \(error.localizedDescription)"
            }
        } else {
            // Regular chat response
            do {
                return try await geminiService.generateResponse(prompt: message)
            } catch {
                return "Sorry, I encountered an error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Handle Input (from UI)

    func handleInput(_ input: String) {
        Task {
            let response = await handleUserMessage(input)
            print("AI Response: \(response)")
        }
    }

    // MARK: - Automatic Intent Detection from Browsing

    func analyzeRecentBrowsing() async {
        guard let session = sessionManager else { return }

        let tabsWithViews = session.getWebTabsWithViews()

        // Need at least 2 tabs for meaningful analysis
        guard tabsWithViews.count >= 2 else {
            await MainActor.run {
                self.pendingSuggestion = nil
                self.showSuggestionBanner = false
            }
            return
        }

        // Extract content from open tabs
        let extractedContents = await contentExtractor.extractAllTabs(webTabs: tabsWithViews)

        print("Analyzing \(extractedContents.count) tabs for intent...")

        // Use the intent classifier
        let analysis = await intentClassifier.analyze(contents: extractedContents)

        // Check if we should show a suggestion
        if analysis.shouldSuggestGenTab && analysis.confidence >= 0.6 {
            // Check if this suggestion was already dismissed
            let suggestionHash = createSuggestionHash(analysis)
            guard !dismissedSuggestionHashes.contains(suggestionHash) else {
                print("Suggestion already dismissed, skipping")
                return
            }

            print("Intent detected: \(analysis.suggestedTitle ?? "Unknown") (confidence: \(analysis.confidence))")

            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.pendingSuggestion = analysis
                    self.showSuggestionBanner = true
                }
            }
        } else {
            print("No actionable intent detected (confidence: \(analysis.confidence))")
        }
    }

    // MARK: - Suggestion Actions

    /// Accept the pending suggestion and generate a GenTab
    func acceptSuggestion() async {
        guard let suggestion = pendingSuggestion else { return }

        print("Accepting suggestion: \(suggestion.suggestedTitle ?? "Unknown")")

        // Get content from related tabs
        let contents = await extractOpenTabContents()
        let relevantContents = contents.filter { suggestion.relatedTabIds.contains($0.tabId) }

        // Build the prompt from tab contents
        let contextParts = relevantContents.map { content in
            "[\(content.domain)] \(content.title): \(String(content.textContent.prefix(500)))"
        }
        let context = contextParts.joined(separator: "\n\n")

        let prompt = """
        Create a \(suggestion.suggestedTitle ?? "helpful") GenTab based on this browsing context:

        \(context)

        Category: \(suggestion.detectedCategory?.rawValue ?? "General")
        """

        // Create source attributions
        let sourceAttrs = relevantContents.map { content in
            SourceAttribution(url: content.url, title: content.title, domain: content.domain)
        }

        do {
            let genTab = try await geminiService.buildGenTab(for: prompt, sourceURLs: sourceAttrs)

            await MainActor.run {
                self.recentGenTabs.append(genTab)
                self.sessionManager?.addGenTab(genTab)
                self.pendingSuggestion = nil
                self.showSuggestionBanner = false
            }

            NotificationCenter.default.post(
                name: NSNotification.Name("genTabCreated"),
                object: nil,
                userInfo: ["genTab": genTab]
            )

            print("GenTab created: \(genTab.title)")
        } catch {
            print("Failed to create GenTab: \(error)")

            await MainActor.run {
                self.pendingSuggestion = nil
                self.showSuggestionBanner = false
            }
        }
    }

    /// Dismiss the pending suggestion
    func dismissSuggestion() {
        guard let suggestion = pendingSuggestion else { return }

        // Remember this suggestion so we don't show it again
        let hash = createSuggestionHash(suggestion)
        dismissedSuggestionHashes.insert(hash)

        withAnimation(.easeOut(duration: 0.2)) {
            pendingSuggestion = nil
            showSuggestionBanner = false
        }

        print("Suggestion dismissed")
    }

    /// Create a hash to identify a suggestion (for deduplication)
    private func createSuggestionHash(_ analysis: IntentClassifier.Analysis) -> String {
        let tabIds = analysis.relatedTabIds.map { $0.uuidString }.sorted().joined()
        return "\(analysis.suggestedTitle ?? "")-\(tabIds.prefix(50))"
    }

    /// Clear dismissed suggestions (e.g., when tabs change significantly)
    func clearDismissedSuggestions() {
        dismissedSuggestionHashes.removeAll()
    }

    // MARK: - Extract Content

    /// Extract content from all open tabs (for manual trigger or chat context)
    func extractOpenTabContents() async -> [ContentExtractor.ExtractedContent] {
        guard let session = sessionManager else { return [] }

        let tabsWithViews = session.getWebTabsWithViews()
        return await contentExtractor.extractAllTabs(webTabs: tabsWithViews)
    }

    // MARK: - Notifications

    private func showIntentNotification(_ intent: SemanticIntent) {
        let notification = NSUserNotification()
        notification.title = "Canvas Detected"
        notification.informativeText = intent.description
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.actionButtonTitle = "Show"
        notification.hasActionButton = true

        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - URL Analysis

    func analyzeURL(_ url: URL) {
        Task {
            do {
                let genTab = try await geminiService.buildGenTab(for: "Analyze this URL: \(url.absoluteString)")
                await MainActor.run {
                    self.recentGenTabs.append(genTab)
                    self.sessionManager?.addGenTab(genTab)
                }

                NotificationCenter.default.post(
                    name: NSNotification.Name("genTabCreated"),
                    object: nil,
                    userInfo: ["genTab": genTab]
                )
            } catch {
                print("URL analysis failed: \(error)")
            }
        }
    }

    // MARK: - Text Analysis

    func analyzeText(_ text: String) {
        Task {
            let response = await handleUserMessage(text)
            print("Text analysis result: \(response)")
        }
    }
}
