import AppIntents
import Foundation

/// Focus Filter for Canvas Browser that integrates with macOS Focus modes
struct CanvasFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Canvas Browser Focus"
    static var description: IntentDescription? = IntentDescription("Configure Canvas Browser behavior during Focus modes")

    /// Whether to hide social media bookmarks
    @Parameter(title: "Hide Social Media Bookmarks", default: false)
    var hideSocialBookmarks: Bool

    /// Whether to block distracting websites
    @Parameter(title: "Block Distracting Sites", default: false)
    var blockDistractingSites: Bool

    /// Whether to disable AI suggestions
    @Parameter(title: "Disable AI Suggestions", default: false)
    var disableAISuggestions: Bool

    /// Whether to use simplified UI
    @Parameter(title: "Simplified UI", default: false)
    var useSimplifiedUI: Bool

    /// Custom blocked domains (comma-separated)
    @Parameter(title: "Custom Blocked Domains", default: "")
    var customBlockedDomains: String

    static var parameterSummary: some ParameterSummary {
        Summary("Configure Canvas Browser Focus") {
            \.$hideSocialBookmarks
            \.$blockDistractingSites
            \.$disableAISuggestions
            \.$useSimplifiedUI
            \.$customBlockedDomains
        }
    }

    /// Display configuration for Focus settings
    var displayRepresentation: DisplayRepresentation {
        var features: [String] = []
        if hideSocialBookmarks { features.append("Hide social") }
        if blockDistractingSites { features.append("Block distractions") }
        if disableAISuggestions { features.append("No AI suggestions") }
        if useSimplifiedUI { features.append("Simplified UI") }

        let subtitle = features.isEmpty ? "No restrictions" : features.joined(separator: ", ")

        return DisplayRepresentation(
            title: "Canvas Browser Focus",
            subtitle: "\(subtitle)",
            image: .init(systemName: "moon.fill")
        )
    }

    func perform() async throws -> some IntentResult {
        // Create focus configuration
        let config = FocusConfiguration(
            hideSocialBookmarks: hideSocialBookmarks,
            blockDistractingSites: blockDistractingSites,
            disableAISuggestions: disableAISuggestions,
            useSimplifiedUI: useSimplifiedUI,
            customBlockedDomains: parseBlockedDomains()
        )

        // Save and apply focus configuration
        await MainActor.run {
            FocusFilterManager.shared.applyConfiguration(config)
        }

        return .result()
    }

    private func parseBlockedDomains() -> [String] {
        customBlockedDomains
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Focus Configuration

struct FocusConfiguration: Codable, Equatable {
    var hideSocialBookmarks: Bool
    var blockDistractingSites: Bool
    var disableAISuggestions: Bool
    var useSimplifiedUI: Bool
    var customBlockedDomains: [String]

    static let `default` = FocusConfiguration(
        hideSocialBookmarks: false,
        blockDistractingSites: false,
        disableAISuggestions: false,
        useSimplifiedUI: false,
        customBlockedDomains: []
    )
}
