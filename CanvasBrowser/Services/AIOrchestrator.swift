import Foundation
import SwiftUI
import Combine

class AIOrchestrator: ObservableObject {
    @Published var currentIntent: SemanticIntent?
    @Published var suggestedActions: [AIAction] = []
    @Published var recentGenTabs: [GenTab] = []
    
    private let geminiService: GeminiService
    private let historyManager: HistoryManager
    private var intentTimer: Timer?
    
    init(geminiService: GeminiService, historyManager: HistoryManager) {
        self.geminiService = geminiService
        self.historyManager = historyManager
        
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
    
    // MARK: - Handle User Messages
    
    func handleUserMessage(_ message: String) async -> String {
        // Priority: Check if this should create a GenTab before standard text generation
        let shouldCreate = await geminiService.shouldCreateGenTab(for: message)
        
        if shouldCreate {
            do {
                let genTab = try await geminiService.buildGenTab(for: message)
                
                await MainActor.run {
                    self.recentGenTabs.append(genTab)
                }
                
                // Notify UI to show GenTab
                NotificationCenter.default.post(
                    name: NSNotification.Name("genTabCreated"),
                    object: nil,
                    userInfo: ["genTab": genTab]
                )
                
                return "I've created a \(genTab.title) app for you. Click 'Open GenTab' to view it."
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
        let recentHistory = historyManager.getRecentHistory(limit: 10)
        
        guard recentHistory.count >= 3 else { return }
        
        let urls = recentHistory.map { $0.url }
        let titles = recentHistory.map { $0.title }
        
        do {
            if let genTab = try await geminiService.analyzeURLsForGenTab(urls: urls, titles: titles) {
                await MainActor.run {
                    let intent = SemanticIntent(
                        intentDetected: true,
                        intentType: "custom",
                        title: genTab.title,
                        menuBarTitle: String(genTab.title.prefix(15)),
                        description: "Based on your recent browsing",
                        icon: genTab.icon,
                        confidence: 0.8,
                        sourceURLs: urls,
                        suggestedActions: genTab.availableActions.map { action in
                            AIAction(title: action, subtitle: "Quick action", icon: "bolt.fill", actionType: "custom")
                        },
                        createdAt: Date()
                    )
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self.currentIntent = intent
                    }
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("aiIntentDetected"),
                        object: intent
                    )
                    
                    showIntentNotification(intent)
                }
            }
        } catch {
            print("Intent detection failed: \(error)")
        }
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


// MARK: - GenTab Models

// MARK: - HistoryManager Extension

// extension HistoryManager {
//     func getRecentHistory(limit: Int) -> [HistoryItem] {
//         // Return recent history entries
//         // This should fetch from your Core Data or database
//         return []  // Placeholder - implement based on your storage
//     }
// }