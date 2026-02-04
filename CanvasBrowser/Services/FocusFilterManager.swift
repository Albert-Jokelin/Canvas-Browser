import Foundation
import Combine
import os.log

/// Manages Focus mode filter state and URL blocking
@MainActor
class FocusFilterManager: ObservableObject {
    static let shared = FocusFilterManager()

    // MARK: - Published Properties

    @Published var currentConfiguration: FocusConfiguration = .default
    @Published var isFocusModeActive = false
    @Published var blockedNavigationAttempts: [BlockedNavigationAttempt] = []

    // MARK: - Default Block Lists

    /// Social media domains to hide when focus is active
    static let socialMediaDomains = [
        "facebook.com", "www.facebook.com", "m.facebook.com",
        "twitter.com", "www.twitter.com", "x.com", "www.x.com",
        "instagram.com", "www.instagram.com",
        "tiktok.com", "www.tiktok.com",
        "reddit.com", "www.reddit.com", "old.reddit.com",
        "linkedin.com", "www.linkedin.com",
        "pinterest.com", "www.pinterest.com",
        "snapchat.com", "www.snapchat.com",
        "tumblr.com", "www.tumblr.com",
        "discord.com", "www.discord.com"
    ]

    /// Distracting sites to block during focus
    static let distractingSiteDomains = [
        "youtube.com", "www.youtube.com", "m.youtube.com",
        "netflix.com", "www.netflix.com",
        "hulu.com", "www.hulu.com",
        "disneyplus.com", "www.disneyplus.com",
        "hbomax.com", "www.hbomax.com", "max.com", "www.max.com",
        "twitch.tv", "www.twitch.tv",
        "9gag.com", "www.9gag.com",
        "buzzfeed.com", "www.buzzfeed.com",
        "imgur.com", "www.imgur.com"
    ]

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.canvas.browser", category: "FocusFilter")
    private let configKey = "canvas_focus_configuration"

    // MARK: - Initialization

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration Management

    func applyConfiguration(_ config: FocusConfiguration) {
        currentConfiguration = config
        isFocusModeActive = config != .default
        saveConfiguration()

        logger.info("Focus configuration applied: social=\(config.hideSocialBookmarks), distracting=\(config.blockDistractingSites), ai=\(config.disableAISuggestions)")

        // Notify observers
        NotificationCenter.default.post(name: .focusFilterChanged, object: config)
    }

    func resetConfiguration() {
        applyConfiguration(.default)
        blockedNavigationAttempts.removeAll()
        logger.info("Focus configuration reset to default")
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(currentConfiguration) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configKey),
              let config = try? JSONDecoder().decode(FocusConfiguration.self, from: data) else {
            return
        }
        currentConfiguration = config
        isFocusModeActive = config != .default
    }

    // MARK: - URL Blocking

    /// Check if a URL should be blocked based on current focus configuration
    func shouldBlockURL(_ url: URL) -> BlockResult {
        guard isFocusModeActive else {
            return .allowed
        }

        guard let host = url.host?.lowercased() else {
            return .allowed
        }

        // Check custom blocked domains first
        for domain in currentConfiguration.customBlockedDomains {
            if host == domain || host.hasSuffix(".\(domain)") {
                recordBlockedAttempt(url: url, reason: .customBlock)
                return .blocked(reason: .customBlock)
            }
        }

        // Check distracting sites
        if currentConfiguration.blockDistractingSites {
            for domain in Self.distractingSiteDomains {
                if host == domain || host.hasSuffix(".\(domain.replacingOccurrences(of: "www.", with: ""))") {
                    recordBlockedAttempt(url: url, reason: .distractingSite)
                    return .blocked(reason: .distractingSite)
                }
            }
        }

        // Check social media (these are hidden in bookmarks, not blocked in navigation)
        // Social media URLs are not blocked during navigation, only hidden in bookmark list

        return .allowed
    }

    /// Check if a bookmark should be hidden based on current focus configuration
    func shouldHideBookmark(_ bookmark: Bookmark) -> Bool {
        guard isFocusModeActive && currentConfiguration.hideSocialBookmarks else {
            return false
        }

        guard let host = URL(string: bookmark.url)?.host?.lowercased() else {
            return false
        }

        // Check if it's a social media bookmark
        for domain in Self.socialMediaDomains {
            if host == domain || host.hasSuffix(".\(domain.replacingOccurrences(of: "www.", with: ""))") {
                return true
            }
        }

        return false
    }

    /// Filter bookmarks based on focus configuration
    func filterBookmarks(_ bookmarks: [Bookmark]) -> [Bookmark] {
        guard isFocusModeActive && currentConfiguration.hideSocialBookmarks else {
            return bookmarks
        }

        return bookmarks.filter { !shouldHideBookmark($0) }
    }

    /// Check if AI suggestions should be shown
    func shouldShowAISuggestions() -> Bool {
        !isFocusModeActive || !currentConfiguration.disableAISuggestions
    }

    /// Check if simplified UI should be used
    func shouldUseSimplifiedUI() -> Bool {
        isFocusModeActive && currentConfiguration.useSimplifiedUI
    }

    // MARK: - Blocked Navigation Tracking

    private func recordBlockedAttempt(url: URL, reason: BlockReason) {
        let attempt = BlockedNavigationAttempt(
            url: url,
            reason: reason,
            timestamp: Date()
        )

        blockedNavigationAttempts.append(attempt)

        // Keep only last 50 attempts
        if blockedNavigationAttempts.count > 50 {
            blockedNavigationAttempts.removeFirst(blockedNavigationAttempts.count - 50)
        }

        logger.info("Blocked navigation to \(url.absoluteString): \(reason.description)")
    }

    func clearBlockedAttempts() {
        blockedNavigationAttempts.removeAll()
    }

    // MARK: - Temporary Override

    private var temporaryOverrideUntil: Date?

    /// Temporarily allow all sites for a specified duration
    func temporarilyAllowAll(duration: TimeInterval) {
        temporaryOverrideUntil = Date().addingTimeInterval(duration)
        logger.info("Temporary override enabled for \(duration) seconds")

        // Schedule reset
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.temporaryOverrideUntil = nil
        }
    }

    var isTemporaryOverrideActive: Bool {
        if let until = temporaryOverrideUntil {
            return Date() < until
        }
        return false
    }

    // MARK: - Statistics

    var blockStatistics: BlockStatistics {
        let socialBlocks = blockedNavigationAttempts.filter { $0.reason == .socialMedia }.count
        let distractingBlocks = blockedNavigationAttempts.filter { $0.reason == .distractingSite }.count
        let customBlocks = blockedNavigationAttempts.filter { $0.reason == .customBlock }.count

        return BlockStatistics(
            totalBlocked: blockedNavigationAttempts.count,
            socialMediaBlocked: socialBlocks,
            distractingSitesBlocked: distractingBlocks,
            customDomainsBlocked: customBlocks
        )
    }
}

// MARK: - Block Result

enum BlockResult: Equatable {
    case allowed
    case blocked(reason: BlockReason)

    var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }
}

// MARK: - Block Reason

enum BlockReason: String, Codable {
    case socialMedia = "social_media"
    case distractingSite = "distracting_site"
    case customBlock = "custom_block"

    var description: String {
        switch self {
        case .socialMedia: return "Social media"
        case .distractingSite: return "Distracting site"
        case .customBlock: return "Custom blocked domain"
        }
    }

    var icon: String {
        switch self {
        case .socialMedia: return "person.2.slash"
        case .distractingSite: return "tv.slash"
        case .customBlock: return "xmark.shield"
        }
    }
}

// MARK: - Blocked Navigation Attempt

struct BlockedNavigationAttempt: Identifiable {
    let id = UUID()
    let url: URL
    let reason: BlockReason
    let timestamp: Date
}

// MARK: - Block Statistics

struct BlockStatistics {
    let totalBlocked: Int
    let socialMediaBlocked: Int
    let distractingSitesBlocked: Int
    let customDomainsBlocked: Int
}

// MARK: - Notification Names

extension Notification.Name {
    static let focusFilterChanged = Notification.Name("com.canvas.browser.focusFilterChanged")
}
