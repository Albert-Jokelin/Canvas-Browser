import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarShelfController: MenuBarShelfController?
    var aiOrchestrator: AIOrchestrator?
    private var isSetup = false

    // MARK: - Handoff
    private let handoffManager = HandoffManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize the Menu Bar Dynamic Shelf (single menu bar icon)
        menuBarShelfController = MenuBarShelfController.shared
        menuBarShelfController?.setupMenuBar()

        // Initialize iCloud sync (deferred - won't crash if not configured)
        Task { @MainActor in
            // Give the app a moment to fully launch before checking CloudKit
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await CloudKitManager.shared.initializeIfNeeded()
        }

        // Setup intent notification observers
        setupIntentObservers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)

        // Clean up shelf controller
        menuBarShelfController?.cleanup()

        // Invalidate Handoff activities
        handoffManager.invalidateAllActivities()

        // Stop proactive suggestions
        ProactiveSuggestionsManager.shared.stopUpdates()

        // Cleanup SharePlay
        SharePlayManager.shared.cleanup()
    }

    func setup(aiOrchestrator: AIOrchestrator) {
        // Guard against multiple setup calls
        guard !isSetup else {
            #if DEBUG
            print("[AppDelegate] setup() called but already setup - ignoring")
            #endif
            return
        }
        isSetup = true

        self.aiOrchestrator = aiOrchestrator

        // Pass the orchestrator to the shelf controller for AI features
        menuBarShelfController?.aiOrchestrator = aiOrchestrator
    }

    // MARK: - Handoff Continuation

    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        // Handle incoming Handoff activity
        guard let result = handoffManager.handleIncomingActivity(userActivity) else {
            return false
        }

        switch result {
        case .openURL(let url, _):
            NotificationCenter.default.post(
                name: .openURLFromIntent,
                object: nil,
                userInfo: ["url": url.absoluteString, "newTab": true]
            )
            return true

        case .openGenTab(let genTab):
            NotificationCenter.default.post(
                name: .openGenTabFromIntent,
                object: nil,
                userInfo: ["genTab": genTab]
            )
            return true

        case .openGenTabById(let id):
            NotificationCenter.default.post(
                name: .openGenTabFromIntent,
                object: nil,
                userInfo: ["genTabId": id.uuidString]
            )
            return true

        case .openChat(let history):
            NotificationCenter.default.post(
                name: .toggleAIPanelFromIntent,
                object: nil,
                userInfo: history.map { ["chatHistory": $0] }
            )
            return true

        case .performSearch(let query):
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let searchURL = "https://www.google.com/search?q=\(encodedQuery)"
            NotificationCenter.default.post(
                name: .openURLFromIntent,
                object: nil,
                userInfo: ["url": searchURL, "newTab": true]
            )
            return true
        }
    }

    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        // Return true if we can handle this activity type
        return HandoffManager.ActivityType(rawValue: userActivityType) != nil
    }

    func application(_ application: NSApplication, didFailToContinueUserActivityWithType userActivityType: String, error: Error) {
        // Log Handoff failures
        print("[AppDelegate] Handoff failed for \(userActivityType): \(error.localizedDescription)")
    }

    // MARK: - Intent Notification Observers

    private func setupIntentObservers() {
        // Open URL from Siri/Shortcuts
        NotificationCenter.default.addObserver(forName: .openURLFromIntent, object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo,
                  let urlString = userInfo["url"] as? String else { return }

            // This will be handled by the main app through AppState
            print("[AppDelegate] Intent: Open URL - \(urlString)")
        }

        // Create GenTab from Siri/Shortcuts
        NotificationCenter.default.addObserver(forName: .createGenTabFromIntent, object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo,
                  let topic = userInfo["topic"] as? String else { return }

            print("[AppDelegate] Intent: Create GenTab - \(topic)")
        }

        // Ask AI from Siri/Shortcuts
        NotificationCenter.default.addObserver(forName: .askAIFromIntent, object: nil, queue: .main) { notification in
            guard let userInfo = notification.userInfo,
                  let question = userInfo["question"] as? String else { return }

            print("[AppDelegate] Intent: Ask AI - \(question)")
        }
    }
}

extension Notification.Name {
    static let aiIntentDetected = Notification.Name("aiIntentDetected")
}
