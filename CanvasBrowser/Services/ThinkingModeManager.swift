import Foundation
import SwiftUI
import Combine

/// Manages AI thinking mode with step-by-step reasoning display
class ThinkingModeManager: ObservableObject {
    static let shared = ThinkingModeManager()

    @Published var isThinking = false
    @Published var thinkingSteps: [ThinkingStep] = []
    @Published var currentThought: String = ""
    @Published var thinkingProgress: Double = 0

    /// Whether internet access is enabled for AI queries
    @AppStorage("enableAIWebSearch") var internetAccessEnabled = false

    /// Whether auto-thinking mode is enabled
    @AppStorage("autoThinkingMode") var autoThinkingEnabled = true

    /// Thinking budget in tokens
    @AppStorage("thinkingBudgetTokens") var thinkingBudgetTokens: Double = 8192

    private let complexityAnalyzer = QueryComplexityAnalyzer()
    private var thinkingTask: Task<Void, Never>?

    private init() {}

    // MARK: - Thinking Step Model

    struct ThinkingStep: Identifiable {
        let id = UUID()
        let content: String
        let timestamp: Date
        let type: StepType

        enum StepType {
            case analyzing
            case reasoning
            case searching
            case concluding
        }

        var icon: String {
            switch type {
            case .analyzing: return "magnifyingglass"
            case .reasoning: return "brain"
            case .searching: return "globe"
            case .concluding: return "checkmark.circle"
            }
        }

        var color: Color {
            switch type {
            case .analyzing: return .blue
            case .reasoning: return .purple
            case .searching: return .green
            case .concluding: return .orange
            }
        }
    }

    // MARK: - Query Analysis

    /// Determine if a query should trigger thinking mode
    func shouldUseThinkingMode(for query: String) -> Bool {
        guard autoThinkingEnabled else { return false }
        return complexityAnalyzer.shouldUseThinking(query: query, autoThinkingEnabled: true)
    }

    /// Analyze query complexity
    func analyzeComplexity(_ query: String) -> QueryComplexityAnalyzer.Complexity {
        return complexityAnalyzer.analyze(query: query)
    }

    // MARK: - Thinking Mode Execution

    /// Generate a response with thinking mode, showing step-by-step reasoning
    func generateWithThinking(
        prompt: String,
        geminiService: GeminiService,
        onStep: ((ThinkingStep) -> Void)? = nil
    ) async throws -> String {
        await MainActor.run {
            isThinking = true
            thinkingSteps = []
            currentThought = "Analyzing query..."
            thinkingProgress = 0.1
        }

        // Add initial analysis step
        await addStep("Analyzing the complexity of your request...", type: .analyzing, onStep: onStep)

        // Check if we need web search
        var searchContext = ""
        if internetAccessEnabled && WebSearchService.shared.needsWebSearch(query: prompt) {
            await addStep("Searching the web for current information...", type: .searching, onStep: onStep)
            await MainActor.run { thinkingProgress = 0.3 }

            do {
                let results = try await WebSearchService.shared.search(query: prompt)
                searchContext = WebSearchService.shared.formatResultsAsContext(results)
                await addStep("Found \(results.count) relevant sources", type: .searching, onStep: onStep)
            } catch {
                await addStep("Web search unavailable, proceeding with knowledge base", type: .searching, onStep: onStep)
            }
        }

        await MainActor.run { thinkingProgress = 0.4 }

        // Build the thinking prompt
        let thinkingPrompt = buildThinkingPrompt(userQuery: prompt, searchContext: searchContext)

        await addStep("Reasoning through the problem step-by-step...", type: .reasoning, onStep: onStep)
        await MainActor.run { thinkingProgress = 0.5 }

        // Call Gemini with thinking model
        let response: String
        do {
            response = try await geminiService.generateResponseWithThinking(prompt: thinkingPrompt)
        } catch {
            // Fallback to regular response if thinking model fails
            response = try await geminiService.generateResponse(prompt: prompt)
        }

        await MainActor.run { thinkingProgress = 0.8 }

        // Parse and display thinking steps from response
        let (thinkingContent, finalAnswer) = parseThinkingResponse(response)

        if let thinking = thinkingContent {
            let steps = thinking.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for step in steps.prefix(5) {
                await addStep(step.trimmingCharacters(in: .whitespaces), type: .reasoning, onStep: onStep)
            }
        }

        await addStep("Formulating final response...", type: .concluding, onStep: onStep)
        await MainActor.run {
            thinkingProgress = 1.0
            isThinking = false
            currentThought = ""
        }

        return finalAnswer ?? response
    }

    /// Generate response with internet access
    func generateWithInternet(
        prompt: String,
        geminiService: GeminiService
    ) async throws -> String {
        guard internetAccessEnabled else {
            return try await geminiService.generateResponse(prompt: prompt)
        }

        // Search web first
        var augmentedPrompt = prompt

        if WebSearchService.shared.needsWebSearch(query: prompt) {
            do {
                let results = try await WebSearchService.shared.search(query: prompt)
                let context = WebSearchService.shared.formatResultsAsContext(results)
                augmentedPrompt = context + "\n\nUser Query: " + prompt
            } catch {
                // Continue without search results
            }
        }

        return try await geminiService.generateResponse(prompt: augmentedPrompt)
    }

    // MARK: - Helpers

    private func buildThinkingPrompt(userQuery: String, searchContext: String) -> String {
        var prompt = """
        Think through this request carefully and show your reasoning process.

        """

        if !searchContext.isEmpty {
            prompt += """
            Web Search Results:
            \(searchContext)

            """
        }

        prompt += """
        User Request: \(userQuery)

        Instructions:
        1. Break down the problem into clear steps
        2. Consider different approaches or perspectives
        3. If applicable, evaluate trade-offs
        4. Provide a well-reasoned conclusion

        Think step by step, then provide your final answer.
        """

        return prompt
    }

    private func parseThinkingResponse(_ response: String) -> (thinking: String?, answer: String?) {
        // Try to extract thinking and answer sections
        if let thinkingStart = response.range(of: "<thinking>"),
           let thinkingEnd = response.range(of: "</thinking>") {
            let thinking = String(response[thinkingStart.upperBound..<thinkingEnd.lowerBound])

            var answer: String? = nil
            if let answerStart = response.range(of: "<answer>"),
               let answerEnd = response.range(of: "</answer>") {
                answer = String(response[answerStart.upperBound..<answerEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return (thinking.trimmingCharacters(in: .whitespacesAndNewlines), answer)
        }

        // No explicit tags, return the whole response
        return (nil, response)
    }

    @MainActor
    private func addStep(_ content: String, type: ThinkingStep.StepType, onStep: ((ThinkingStep) -> Void)?) {
        let step = ThinkingStep(content: content, timestamp: Date(), type: type)
        thinkingSteps.append(step)
        currentThought = content
        onStep?(step)
    }

    func reset() {
        thinkingTask?.cancel()
        isThinking = false
        thinkingSteps = []
        currentThought = ""
        thinkingProgress = 0
    }
}

// MARK: - Thinking Steps View

struct ThinkingStepsView: View {
    @ObservedObject var manager: ThinkingModeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with progress
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                Text("Thinking...")
                    .font(.headline)
                Spacer()
                Text("\(Int(manager.thinkingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Progress bar
            ProgressView(value: manager.thinkingProgress)
                .progressViewStyle(.linear)
                .tint(.purple)

            // Current thought
            if !manager.currentThought.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(manager.currentThought)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }

            // Steps list
            if !manager.thinkingSteps.isEmpty {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(manager.thinkingSteps) { step in
                            ThinkingStepRow(step: step)
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ThinkingStepRow: View {
    let step: ThinkingModeManager.ThinkingStep

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: step.icon)
                .font(.caption)
                .foregroundColor(step.color)
                .frame(width: 16)

            Text(step.content)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            Text(step.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Thinking Mode Indicator

struct ThinkingModeIndicator: View {
    @ObservedObject var manager = ThinkingModeManager.shared
    @State private var rotation: Double = 0

    var body: some View {
        if manager.isThinking {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.caption)
                    .foregroundColor(.purple)
                    .rotationEffect(.degrees(rotation))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: rotation)

                Text("Thinking...")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(8)
            .onAppear {
                rotation = 360
            }
        }
    }
}
