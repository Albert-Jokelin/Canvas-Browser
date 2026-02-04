import AppIntents
import Foundation

// MARK: - Search Intent

/// Performs a web search in Canvas Browser
struct SearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Search in Canvas"
    static var description = IntentDescription("Search the web using Canvas Browser")

    @Parameter(title: "Search Query", description: "What to search for")
    var query: String

    @Parameter(title: "Open in New Tab", default: true)
    var openInNewTab: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query)") {
            \.$openInNewTab
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Construct search URL
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = "https://www.google.com/search?q=\(encodedQuery)"

        // Post notification to open URL
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openURLFromIntent,
                object: nil,
                userInfo: ["url": searchURL, "newTab": openInNewTab]
            )
        }

        return .result(value: "Searching for: \(query)")
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Open URL Intent

/// Opens a specific URL in Canvas Browser
struct OpenURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Open URL in Canvas"
    static var description = IntentDescription("Open a webpage in Canvas Browser")

    @Parameter(title: "URL", description: "The URL to open")
    var url: String

    @Parameter(title: "Open in New Tab", default: true)
    var openInNewTab: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$url) in Canvas") {
            \.$openInNewTab
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Validate and normalize URL
        var normalizedURL = url
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            normalizedURL = "https://\(url)"
        }

        guard URL(string: normalizedURL) != nil else {
            throw IntentError.invalidURL
        }

        await MainActor.run {
            NotificationCenter.default.post(
                name: .openURLFromIntent,
                object: nil,
                userInfo: ["url": normalizedURL, "newTab": openInNewTab]
            )
        }

        return .result(value: "Opening: \(normalizedURL)")
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Create GenTab Intent

/// Creates a new AI-generated GenTab
struct CreateGenTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Create GenTab"
    static var description = IntentDescription("Create an AI-generated interactive tab in Canvas Browser")

    @Parameter(title: "Topic", description: "What the GenTab should be about")
    var topic: String

    @Parameter(title: "Type", description: "The type of GenTab to create")
    var genTabType: GenTabTypeOption

    static var parameterSummary: some ParameterSummary {
        Summary("Create a \(\.$genTabType) GenTab about \(\.$topic)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .createGenTabFromIntent,
                object: nil,
                userInfo: ["topic": topic, "type": genTabType.rawValue]
            )
        }

        return .result(value: "Creating GenTab: \(topic)")
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - GenTab Type Option

enum GenTabTypeOption: String, AppEnum {
    case cards = "cards"
    case map = "map"
    case comparison = "comparison"
    case summary = "summary"
    case auto = "auto"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "GenTab Type"

    static var caseDisplayRepresentations: [GenTabTypeOption: DisplayRepresentation] = [
        .cards: "Card Grid",
        .map: "Map View",
        .comparison: "Comparison Table",
        .summary: "Summary",
        .auto: "Auto (AI Decides)"
    ]
}

// MARK: - Ask AI Intent

/// Ask Canvas AI a question
struct AskAIIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Canvas AI"
    static var description = IntentDescription("Ask Canvas Browser's AI assistant a question")

    @Parameter(title: "Question", description: "Your question for the AI")
    var question: String

    @Parameter(title: "Include Current Page", description: "Include content from the current page in context", default: false)
    var includeCurrentPage: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Canvas: \(\.$question)") {
            \.$includeCurrentPage
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .askAIFromIntent,
                object: nil,
                userInfo: ["question": question, "includeContext": includeCurrentPage]
            )
        }

        return .result(value: "Asking AI: \(question)")
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Open Bookmark Intent

/// Opens a saved bookmark
struct OpenBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Bookmark"
    static var description = IntentDescription("Open a saved bookmark in Canvas Browser")

    @Parameter(title: "Bookmark")
    var bookmark: BookmarkEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Open bookmark \(\.$bookmark)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .openURLFromIntent,
                object: nil,
                userInfo: ["url": bookmark.url, "newTab": true]
            )
        }

        return .result(value: "Opening bookmark: \(bookmark.title)")
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Add to Reading List Intent

/// Adds current page or URL to reading list
struct AddToReadingListIntent: AppIntent {
    static var title: LocalizedStringResource = "Add to Reading List"
    static var description = IntentDescription("Save a page to your reading list for later")

    @Parameter(title: "URL", description: "The URL to save (uses current page if empty)")
    var url: String?

    @Parameter(title: "Title", description: "Custom title for the item")
    var customTitle: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Add to Reading List") {
            \.$url
            \.$customTitle
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            var userInfo: [String: Any] = [:]
            if let url = url {
                userInfo["url"] = url
            }
            if let title = customTitle {
                userInfo["title"] = title
            }

            NotificationCenter.default.post(
                name: .addToReadingListFromIntent,
                object: nil,
                userInfo: userInfo.isEmpty ? nil : userInfo
            )
        }

        if let url = url {
            return .result(value: "Added to reading list: \(url)")
        } else {
            return .result(value: "Added current page to reading list")
        }
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Summarize Page Intent

/// Uses AI to summarize the current page
struct SummarizePageIntent: AppIntent {
    static var title: LocalizedStringResource = "Summarize Page"
    static var description = IntentDescription("Get an AI-generated summary of the current webpage")

    @Parameter(title: "Summary Length")
    var length: SummaryLength

    static var parameterSummary: some ParameterSummary {
        Summary("Summarize page with \(\.$length) length")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .summarizePageFromIntent,
                object: nil,
                userInfo: ["length": length.rawValue]
            )
        }

        return .result(value: "Generating \(length.rawValue) summary...")
    }

    static var openAppWhenRun: Bool = true
}

enum SummaryLength: String, AppEnum {
    case brief = "brief"
    case detailed = "detailed"
    case bulletPoints = "bullet_points"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Summary Length"

    static var caseDisplayRepresentations: [SummaryLength: DisplayRepresentation] = [
        .brief: "Brief (1-2 sentences)",
        .detailed: "Detailed (paragraph)",
        .bulletPoints: "Bullet Points"
    ]
}

// MARK: - New Tab Intent

/// Opens a new tab in Canvas Browser
struct NewTabIntent: AppIntent {
    static var title: LocalizedStringResource = "New Tab"
    static var description = IntentDescription("Open a new tab in Canvas Browser")

    static var parameterSummary: some ParameterSummary {
        Summary("Open a new tab in Canvas")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .newTabFromIntent, object: nil)
        }
        return .result()
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Toggle AI Panel Intent

/// Shows or hides the AI chat panel
struct ToggleAIPanelIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle AI Panel"
    static var description = IntentDescription("Show or hide the AI chat panel in Canvas Browser")

    @Parameter(title: "Show Panel")
    var show: Bool?

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle AI Panel") {
            \.$show
        }
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .toggleAIPanelFromIntent,
                object: nil,
                userInfo: show.map { ["show": $0] }
            )
        }
        return .result()
    }

    static var openAppWhenRun: Bool = true
}

// MARK: - Get Current URL Intent

/// Returns the URL of the current page (for Shortcuts automation)
struct GetCurrentURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Current URL"
    static var description = IntentDescription("Get the URL of the currently active tab")

    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        // This would need to be connected to AppState
        // For now, post notification and return placeholder
        await MainActor.run {
            NotificationCenter.default.post(name: .getCurrentURLFromIntent, object: nil)
        }

        // In practice, this should retrieve the actual URL
        return .result(value: nil)
    }
}

// MARK: - Get Page Title Intent

/// Returns the title of the current page
struct GetPageTitleIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Page Title"
    static var description = IntentDescription("Get the title of the currently active tab")

    func perform() async throws -> some IntentResult & ReturnsValue<String?> {
        await MainActor.run {
            NotificationCenter.default.post(name: .getPageTitleFromIntent, object: nil)
        }
        return .result(value: nil)
    }
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidURL
    case noActiveTab
    case aiNotAvailable
    case bookmarkNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidURL:
            return "The provided URL is invalid"
        case .noActiveTab:
            return "No active tab is open"
        case .aiNotAvailable:
            return "AI features are not available"
        case .bookmarkNotFound:
            return "Bookmark not found"
        }
    }
}

// MARK: - Notification Names for Intent Communication

extension Notification.Name {
    static let openURLFromIntent = Notification.Name("com.canvas.browser.intent.openURL")
    static let createGenTabFromIntent = Notification.Name("com.canvas.browser.intent.createGenTab")
    static let askAIFromIntent = Notification.Name("com.canvas.browser.intent.askAI")
    static let addToReadingListFromIntent = Notification.Name("com.canvas.browser.intent.addToReadingList")
    static let summarizePageFromIntent = Notification.Name("com.canvas.browser.intent.summarizePage")
    static let newTabFromIntent = Notification.Name("com.canvas.browser.intent.newTab")
    static let toggleAIPanelFromIntent = Notification.Name("com.canvas.browser.intent.toggleAIPanel")
    static let getCurrentURLFromIntent = Notification.Name("com.canvas.browser.intent.getCurrentURL")
    static let getPageTitleFromIntent = Notification.Name("com.canvas.browser.intent.getPageTitle")
}
