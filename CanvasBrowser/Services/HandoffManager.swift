import Foundation
import AppKit
import os.log

/// Manages NSUserActivity for Handoff between Apple devices
@MainActor
class HandoffManager: ObservableObject {
    static let shared = HandoffManager()

    // MARK: - Activity Types

    enum ActivityType: String {
        case browsing = "com.canvas.browser.browsing"
        case genTab = "com.canvas.browser.gentab"
        case chat = "com.canvas.browser.chat"
        case search = "com.canvas.browser.search"

        var title: String {
            switch self {
            case .browsing: return "Browsing"
            case .genTab: return "Viewing GenTab"
            case .chat: return "AI Chat"
            case .search: return "Search"
            }
        }
    }

    // MARK: - UserInfo Keys

    enum UserInfoKey: String {
        case url = "url"
        case title = "title"
        case genTabId = "genTabId"
        case genTabData = "genTabData"
        case chatHistory = "chatHistory"
        case searchQuery = "searchQuery"
        case timestamp = "timestamp"
    }

    // MARK: - Published Properties

    @Published var currentActivity: NSUserActivity?
    @Published var isHandoffAvailable = true

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.canvas.browser", category: "Handoff")
    private var activeActivities: [String: NSUserActivity] = [:]

    // MARK: - Initialization

    private init() {
        checkHandoffAvailability()
    }

    private func checkHandoffAvailability() {
        // Handoff requires Bluetooth and WiFi to be enabled
        // We assume it's available on macOS 14+
        isHandoffAvailable = true
    }

    // MARK: - Activity Management

    /// Start a browsing activity for Handoff
    func startBrowsingActivity(url: URL, title: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.browsing.rawValue)
        activity.title = title
        activity.webpageURL = url
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true
        activity.isEligibleForPublicIndexing = false

        // Add user info for additional context
        activity.userInfo = [
            UserInfoKey.url.rawValue: url.absoluteString,
            UserInfoKey.title.rawValue: title,
            UserInfoKey.timestamp.rawValue: Date()
        ]

        // Set keywords for Spotlight
        activity.keywords = Set([title, url.host ?? ""].filter { !$0.isEmpty })

        // Content attribute set for richer search results
        let attributes = activity.contentAttributeSet ?? CSSearchableItemAttributeSet(contentType: .url)
        attributes.title = title
        attributes.contentURL = url
        attributes.relatedUniqueIdentifier = url.absoluteString
        activity.contentAttributeSet = attributes

        activity.becomeCurrent()
        currentActivity = activity
        activeActivities[ActivityType.browsing.rawValue] = activity

        logger.info("Started browsing activity: \(title) - \(url.absoluteString)")
        return activity
    }

    /// Start a GenTab viewing activity for Handoff
    func startGenTabActivity(genTab: GenTab) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.genTab.rawValue)
        activity.title = "GenTab: \(genTab.title)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        // Encode GenTab data for transfer
        var userInfo: [String: Any] = [
            UserInfoKey.genTabId.rawValue: genTab.id.uuidString,
            UserInfoKey.title.rawValue: genTab.title,
            UserInfoKey.timestamp.rawValue: Date()
        ]

        // Add encoded GenTab data
        if let genTabData = try? JSONEncoder().encode(genTab) {
            userInfo[UserInfoKey.genTabData.rawValue] = genTabData
        }

        activity.userInfo = userInfo
        activity.keywords = Set([genTab.title, "GenTab", "Canvas"])

        activity.becomeCurrent()
        currentActivity = activity
        activeActivities[ActivityType.genTab.rawValue] = activity

        logger.info("Started GenTab activity: \(genTab.title)")
        return activity
    }

    /// Start an AI chat activity for Handoff
    func startChatActivity(chatHistory: [HandoffChatMessage]?) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.chat.rawValue)
        activity.title = "Canvas AI Chat"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false // Chat history shouldn't be indexed

        var userInfo: [String: Any] = [
            UserInfoKey.timestamp.rawValue: Date()
        ]

        // Encode recent chat history (last 10 messages) for transfer
        if let history = chatHistory, !history.isEmpty {
            let recentHistory = Array(history.suffix(10))
            if let historyData = try? JSONEncoder().encode(recentHistory) {
                userInfo[UserInfoKey.chatHistory.rawValue] = historyData
            }
        }

        activity.userInfo = userInfo

        activity.becomeCurrent()
        currentActivity = activity
        activeActivities[ActivityType.chat.rawValue] = activity

        logger.info("Started chat activity")
        return activity
    }

    /// Start a search activity for Handoff
    func startSearchActivity(query: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: ActivityType.search.rawValue)
        activity.title = "Search: \(query)"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = true

        activity.userInfo = [
            UserInfoKey.searchQuery.rawValue: query,
            UserInfoKey.timestamp.rawValue: Date()
        ]

        activity.keywords = Set([query, "search", "Canvas"])

        activity.becomeCurrent()
        currentActivity = activity
        activeActivities[ActivityType.search.rawValue] = activity

        logger.info("Started search activity: \(query)")
        return activity
    }

    /// Update the current browsing activity
    func updateBrowsingActivity(url: URL, title: String) {
        if let activity = activeActivities[ActivityType.browsing.rawValue] {
            activity.title = title
            activity.webpageURL = url
            activity.userInfo?[UserInfoKey.url.rawValue] = url.absoluteString
            activity.userInfo?[UserInfoKey.title.rawValue] = title
            activity.userInfo?[UserInfoKey.timestamp.rawValue] = Date()
            activity.needsSave = true

            logger.debug("Updated browsing activity: \(title)")
        } else {
            _ = startBrowsingActivity(url: url, title: title)
        }
    }

    /// Invalidate the current activity
    func invalidateCurrentActivity() {
        currentActivity?.invalidate()
        currentActivity = nil
        logger.debug("Invalidated current activity")
    }

    /// Invalidate a specific activity type
    func invalidateActivity(type: ActivityType) {
        activeActivities[type.rawValue]?.invalidate()
        activeActivities.removeValue(forKey: type.rawValue)

        if currentActivity?.activityType == type.rawValue {
            currentActivity = nil
        }

        logger.debug("Invalidated \(type.rawValue) activity")
    }

    /// Invalidate all activities
    func invalidateAllActivities() {
        for (_, activity) in activeActivities {
            activity.invalidate()
        }
        activeActivities.removeAll()
        currentActivity = nil
        logger.info("Invalidated all activities")
    }

    // MARK: - Handling Incoming Activities

    /// Handle an incoming Handoff activity
    func handleIncomingActivity(_ activity: NSUserActivity) -> HandoffResult? {
        logger.info("Received Handoff activity: \(activity.activityType)")

        guard let activityType = ActivityType(rawValue: activity.activityType) else {
            logger.warning("Unknown activity type: \(activity.activityType)")
            return nil
        }

        switch activityType {
        case .browsing:
            return handleBrowsingActivity(activity)

        case .genTab:
            return handleGenTabActivity(activity)

        case .chat:
            return handleChatActivity(activity)

        case .search:
            return handleSearchActivity(activity)
        }
    }

    private func handleBrowsingActivity(_ activity: NSUserActivity) -> HandoffResult? {
        // Try webpageURL first, then fall back to userInfo
        if let url = activity.webpageURL {
            let title = activity.title ?? activity.userInfo?[UserInfoKey.title.rawValue] as? String ?? "Untitled"
            return .openURL(url, title: title)
        }

        if let urlString = activity.userInfo?[UserInfoKey.url.rawValue] as? String,
           let url = URL(string: urlString) {
            let title = activity.userInfo?[UserInfoKey.title.rawValue] as? String ?? "Untitled"
            return .openURL(url, title: title)
        }

        logger.error("Browsing activity missing URL")
        return nil
    }

    private func handleGenTabActivity(_ activity: NSUserActivity) -> HandoffResult? {
        // Try to decode the full GenTab
        if let genTabData = activity.userInfo?[UserInfoKey.genTabData.rawValue] as? Data,
           let genTab = try? JSONDecoder().decode(GenTab.self, from: genTabData) {
            return .openGenTab(genTab)
        }

        // Fall back to just the ID
        if let genTabIdString = activity.userInfo?[UserInfoKey.genTabId.rawValue] as? String,
           let genTabId = UUID(uuidString: genTabIdString) {
            return .openGenTabById(genTabId)
        }

        logger.error("GenTab activity missing data")
        return nil
    }

    private func handleChatActivity(_ activity: NSUserActivity) -> HandoffResult? {
        var chatHistory: [HandoffChatMessage]?

        if let historyData = activity.userInfo?[UserInfoKey.chatHistory.rawValue] as? Data {
            chatHistory = try? JSONDecoder().decode([HandoffChatMessage].self, from: historyData)
        }

        return .openChat(history: chatHistory)
    }

    private func handleSearchActivity(_ activity: NSUserActivity) -> HandoffResult? {
        if let query = activity.userInfo?[UserInfoKey.searchQuery.rawValue] as? String {
            return .performSearch(query)
        }

        logger.error("Search activity missing query")
        return nil
    }

    // MARK: - Activity Restoration

    /// Check if an activity can be continued
    func canContinue(activity: NSUserActivity) -> Bool {
        guard let activityType = ActivityType(rawValue: activity.activityType) else {
            return false
        }

        switch activityType {
        case .browsing:
            return activity.webpageURL != nil ||
                   activity.userInfo?[UserInfoKey.url.rawValue] != nil

        case .genTab:
            return activity.userInfo?[UserInfoKey.genTabId.rawValue] != nil ||
                   activity.userInfo?[UserInfoKey.genTabData.rawValue] != nil

        case .chat:
            return true // Chat can always be continued

        case .search:
            return activity.userInfo?[UserInfoKey.searchQuery.rawValue] != nil
        }
    }
}

// MARK: - Handoff Result

enum HandoffResult {
    case openURL(URL, title: String)
    case openGenTab(GenTab)
    case openGenTabById(UUID)
    case openChat(history: [HandoffChatMessage]?)
    case performSearch(String)
}

// MARK: - Chat Message for Handoff

struct HandoffChatMessage: Codable, Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    enum MessageRole: String, Codable {
        case user
        case assistant
        case system
    }

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

// MARK: - CSSearchableItemAttributeSet import

import CoreSpotlight
