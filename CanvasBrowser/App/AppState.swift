import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var sessionManager: BrowsingSession
    @Published var aiOrchestrator: AIOrchestrator
    
    private var cancellables = Set<AnyCancellable>()
    
    // We'll init the services here
    init() {
        let historyManager = HistoryManager.shared
        // Placeholder for GeminiService, using a basic init for now until Phase 2
        let geminiService = GeminiService() 
        
        self.sessionManager = BrowsingSession()
        self.aiOrchestrator = AIOrchestrator(geminiService: geminiService, historyManager: historyManager)
        
        // Propagate session changes to AppState consumers
        sessionManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        NotificationCenter.default.addObserver(forName: Notification.Name("TriggerDemoGenTab"), object: nil, queue: .main) { [weak self] _ in
            self?.createGenTabFromSelection()
        }
    }
    
    func createGenTabFromSelection() {
        // Create the "Vegetable Garden Planner" demo tab
        let gardenTab = GenTab(
            title: "Vegetable Garden",
            icon: "leaf.fill",
            contentType: .cardGrid,
            items: [
                CardItem(
                    title: "Pepper",
                    description: "Warm-season crop with a variety of shapes, colors, and spice levels.",
                    imageURL: nil, // Placeholder will be used
                    actionTitle: "View Details"
                ),
                CardItem(
                    title: "Summer Squash",
                    description: "Fast-growing warm-season crop including zucchini and yellow squash.",
                    imageURL: nil,
                    actionTitle: "View Details"
                ),
                CardItem(
                    title: "Green Beans",
                    description: "A tender, warm-season vegetable that comes in bush or pole varieties.",
                    imageURL: nil,
                    actionTitle: "View Details"
                ),
                CardItem(
                    title: "Radish",
                    description: "A fast-growing, edible root vegetable known for its peppery flavor.",
                    imageURL: nil,
                    actionTitle: "View Details"
                )
            ],
            locations: [],
            availableActions: ["Planting Calendar", "Regional Dates", "Add More Plants", "Tips"]
        )
        
        // Add to session
        sessionManager.addGenTab(gardenTab)
    }
}
