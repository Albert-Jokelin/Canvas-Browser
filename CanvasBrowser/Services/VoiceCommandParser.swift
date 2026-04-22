import Foundation

// MARK: - Voice Command Enum

enum VoiceCommand: Equatable {
    // Navigation
    case goBack
    case goForward
    case reload
    case stopLoading
    case goHome

    // Tabs
    case newTab
    case closeTab
    case nextTab
    case previousTab
    case switchToTab(Int)

    // URL / Search
    case navigateToURL(String)
    case search(String)

    // Page
    case scrollUp
    case scrollDown
    case scrollToTop
    case scrollToBottom
    case zoomIn
    case zoomOut
    case zoomReset
    case findInPage(String)

    // UI
    case toggleAIChat
    case toggleBookmarks
    case toggleHistory
    case toggleFullscreen
    case openSettings

    // AI
    case askAI(String)
    case createGenTab

    // Browser
    case addBookmark
    case takeScreenshot
    case printPage
    case toggleReaderMode

    // Voice
    case stopListening

    var feedbackDescription: String {
        switch self {
        case .goBack: return "Going back"
        case .goForward: return "Going forward"
        case .reload: return "Reloading page"
        case .stopLoading: return "Stopping"
        case .goHome: return "Going home"
        case .newTab: return "Opening new tab"
        case .closeTab: return "Closing tab"
        case .nextTab: return "Next tab"
        case .previousTab: return "Previous tab"
        case .switchToTab(let n): return "Switching to tab \(n)"
        case .navigateToURL(let url): return "Navigating to \(url)"
        case .search(let query): return "Searching for \(query)"
        case .scrollUp: return "Scrolling up"
        case .scrollDown: return "Scrolling down"
        case .scrollToTop: return "Scrolling to top"
        case .scrollToBottom: return "Scrolling to bottom"
        case .zoomIn: return "Zooming in"
        case .zoomOut: return "Zooming out"
        case .zoomReset: return "Resetting zoom"
        case .findInPage(let text): return "Finding \"\(text)\""
        case .toggleAIChat: return "Toggling AI chat"
        case .toggleBookmarks: return "Toggling bookmarks"
        case .toggleHistory: return "Toggling history"
        case .toggleFullscreen: return "Toggling fullscreen"
        case .openSettings: return "Opening settings"
        case .askAI(let query): return "Asking AI: \(query)"
        case .createGenTab: return "Creating GenTab"
        case .addBookmark: return "Adding bookmark"
        case .takeScreenshot: return "Taking screenshot"
        case .printPage: return "Printing page"
        case .toggleReaderMode: return "Toggling reader mode"
        case .stopListening: return "Stopping voice control"
        }
    }
}

// MARK: - Voice Command Parser

struct VoiceCommandParser {

    func parse(_ text: String) -> VoiceCommand? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        // Multi-word prefix triggers (most specific first)

        // Voice control
        if normalized == "stop listening" || normalized == "cancel" {
            return .stopListening
        }

        // AI commands
        if normalized.hasPrefix("ask ai ") || normalized.hasPrefix("ask a.i. ") {
            let query = String(normalized.dropFirst(normalized.hasPrefix("ask ai ") ? 7 : 9))
            if !query.isEmpty { return .askAI(query) }
        }
        if normalized == "create gen tab" || normalized == "create gentab" || normalized == "new gen tab" || normalized == "new gentab" {
            return .createGenTab
        }

        // Navigation with argument
        if normalized.hasPrefix("go to ") || normalized.hasPrefix("open ") {
            let prefix = normalized.hasPrefix("go to ") ? "go to " : "open "
            let target = String(normalized.dropFirst(prefix.count))
            if let url = normalizeURL(target) {
                return .navigateToURL(url)
            }
            // "open chat", "open settings", etc. handled below
            if target == "chat" || target == "ai chat" || target == "ai panel" { return .toggleAIChat }
            if target == "settings" || target == "preferences" { return .openSettings }
            if target == "bookmarks" { return .toggleBookmarks }
            if target == "history" { return .toggleHistory }
        }

        // Search
        if normalized.hasPrefix("search for ") {
            let query = String(normalized.dropFirst(11))
            if !query.isEmpty { return .search(query) }
        }
        if normalized.hasPrefix("search ") {
            let query = String(normalized.dropFirst(7))
            if !query.isEmpty { return .search(query) }
        }
        if normalized.hasPrefix("google ") {
            let query = String(normalized.dropFirst(7))
            if !query.isEmpty { return .search(query) }
        }

        // Find in page
        if normalized.hasPrefix("find ") {
            let remainder = String(normalized.dropFirst(5))
            if remainder.hasSuffix(" on page") {
                let query = String(remainder.dropLast(8))
                if !query.isEmpty { return .findInPage(query) }
            }
            if remainder.hasSuffix(" in page") {
                let query = String(remainder.dropLast(8))
                if !query.isEmpty { return .findInPage(query) }
            }
            if !remainder.isEmpty { return .findInPage(remainder) }
        }

        // Tab switching by number
        if normalized.hasPrefix("switch to tab ") || normalized.hasPrefix("tab number ") {
            let prefix = normalized.hasPrefix("switch to tab ") ? "switch to tab " : "tab number "
            let numStr = String(normalized.dropFirst(prefix.count))
            if let num = parseNumber(numStr) { return .switchToTab(num) }
        }
        if normalized.hasPrefix("tab ") {
            let numStr = String(normalized.dropFirst(4))
            if let num = parseNumber(numStr) { return .switchToTab(num) }
        }

        // Single-word / short-phrase triggers
        switch normalized {
        // Navigation
        case "go back", "back": return .goBack
        case "go forward", "forward": return .goForward
        case "reload", "refresh": return .reload
        case "stop": return .stopLoading
        case "go home", "home": return .goHome

        // Tabs
        case "new tab": return .newTab
        case "close tab": return .closeTab
        case "next tab": return .nextTab
        case "previous tab", "last tab": return .previousTab

        // Page
        case "scroll up", "up": return .scrollUp
        case "scroll down", "down": return .scrollDown
        case "top of page", "scroll to top", "top": return .scrollToTop
        case "bottom of page", "scroll to bottom", "bottom": return .scrollToBottom
        case "zoom in", "bigger": return .zoomIn
        case "zoom out", "smaller": return .zoomOut
        case "zoom reset", "actual size", "reset zoom": return .zoomReset

        // UI
        case "open chat", "show chat", "toggle chat", "ai chat", "chat": return .toggleAIChat
        case "show bookmarks", "bookmarks": return .toggleBookmarks
        case "show history", "history": return .toggleHistory
        case "full screen", "fullscreen", "toggle fullscreen": return .toggleFullscreen
        case "open settings", "settings", "preferences": return .openSettings

        // Browser
        case "bookmark this", "add bookmark", "bookmark": return .addBookmark
        case "screenshot", "take screenshot": return .takeScreenshot
        case "print page", "print": return .printPage
        case "reader mode", "toggle reader mode", "reading mode": return .toggleReaderMode

        // GenTab
        case "gen tab", "gentab", "create gen tab", "create gentab": return .createGenTab

        default: break
        }

        return nil
    }

    // MARK: - Helpers

    private func normalizeURL(_ input: String) -> String? {
        var cleaned = input
            .replacingOccurrences(of: " dot ", with: ".")
            .replacingOccurrences(of: " slash ", with: "/")
            .replacingOccurrences(of: " ", with: "")

        // Must look like a domain
        guard cleaned.contains(".") else { return nil }

        // Add scheme if missing
        if !cleaned.hasPrefix("http://") && !cleaned.hasPrefix("https://") {
            cleaned = "https://" + cleaned
        }

        return cleaned
    }

    private func parseNumber(_ text: String) -> Int? {
        if let num = Int(text) { return num }

        let wordMap: [String: Int] = [
            "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
            "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
            "first": 1, "second": 2, "third": 3, "fourth": 4, "fifth": 5,
        ]
        return wordMap[text]
    }
}
