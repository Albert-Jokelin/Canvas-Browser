import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var orchestrator: AIOrchestrator
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search/URL input
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Ask or navigate...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        orchestrator.handleInput(searchText)
                    }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Dynamic AI suggestions
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let intent = orchestrator.currentIntent {
                        // Active intent card placeholder
                        Text(intent.title).font(.headline)
                    } else {
                        Text("No active intent detected").font(.caption).foregroundColor(.secondary)
                    }
                    
                    // AI-generated action items
                    ForEach(orchestrator.suggestedActions) { action in
                        HStack {
                            Image(systemName: action.icon)
                            VStack(alignment: .leading) {
                                Text(action.title).font(.body)
                                Text(action.subtitle).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    Button(action: {
                        orchestrator.objectWillChange.send() // Force update if needed, but AppState is main
                        // We need access to AppState here. 
                        // Since text field submit calls orchestrator, we can use a hack or better, pass action.
                        // For now, let's use a loose coupling or Notification.
                        NotificationCenter.default.post(name: Notification.Name("TriggerDemoGenTab"), object: nil)
                    }) {
                        Label("Demo: Create Garden Planner", systemImage: "leaf")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .frame(width: 400, height: 600)
    }
}
