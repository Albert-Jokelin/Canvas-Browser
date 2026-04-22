import Foundation

/// Centralized notification name constants for Canvas Browser
/// Using a single location for all notification names prevents typos and enables refactoring
extension Notification.Name {
    // MARK: - GenTab Notifications

    /// Posted when a new GenTab is created by the AI
    static let genTabCreated = Notification.Name("genTabCreated")

    /// Posted to trigger a demo GenTab (for testing/onboarding)
    static let triggerDemoGenTab = Notification.Name("TriggerDemoGenTab")

    // MARK: - Tab Management Notifications

    /// Posted when a new tab should be created with a specific URL
    static let createNewTabWithURL = Notification.Name("createNewTabWithURL")

    /// Posted when a new private tab should be created with a specific URL
    static let createPrivateTabWithURL = Notification.Name("createPrivateTabWithURL")

    // MARK: - Download Notifications

    /// Posted when a download should be started
    static let startDownload = Notification.Name("startDownload")

    // MARK: - Navigation Notifications

    /// Posted when navigation should go back
    static let navigateBack = Notification.Name("navigateBack")

    /// Posted when navigation should go forward
    static let navigateForward = Notification.Name("navigateForward")

    /// Posted when the current page should be reloaded
    static let reloadPage = Notification.Name("reloadPage")

    // MARK: - UI Notifications

    /// Posted when the chat panel should be toggled
    static let toggleChatPanel = Notification.Name("toggleChatPanel")

    /// Posted when settings should be shown
    static let showSettings = Notification.Name("showSettings")

    // MARK: - AI Notifications

    /// Posted when AI suggestion banner should be shown
    static let showAISuggestion = Notification.Name("showAISuggestion")

    /// Posted when AI suggestion was accepted
    static let aiSuggestionAccepted = Notification.Name("aiSuggestionAccepted")

    /// Posted when AI suggestion was dismissed
    static let aiSuggestionDismissed = Notification.Name("aiSuggestionDismissed")

    // MARK: - Voice Control Notifications

    /// Posted when a voice command wants to send a query to AI chat
    static let voiceAIQuery = Notification.Name("voiceAIQuery")

    /// Posted when a voice command wants to create a GenTab
    static let voiceGenTabRequest = Notification.Name("voiceGenTabRequest")

    /// Posted to toggle voice listening on/off
    static let toggleVoiceControl = Notification.Name("toggleVoiceControl")
}
