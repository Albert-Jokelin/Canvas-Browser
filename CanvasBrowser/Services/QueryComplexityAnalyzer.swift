import Foundation

/// Analyzes query complexity to determine if extended thinking is needed
class QueryComplexityAnalyzer {

    enum Complexity {
        case simple
        case moderate
        case complex

        var description: String {
            switch self {
            case .simple: return "Simple query - standard response"
            case .moderate: return "Moderate query - may benefit from thinking"
            case .complex: return "Complex query - thinking recommended"
            }
        }
    }

    /// Keywords that indicate complex reasoning is needed
    private let complexKeywords = [
        "analyze", "compare", "contrast", "explain why", "explain how",
        "debug", "review", "evaluate", "design", "implement", "refactor",
        "optimize", "troubleshoot", "diagnose", "investigate", "research",
        "plan", "strategy", "architecture", "trade-off", "tradeoff",
        "pros and cons", "advantages", "disadvantages", "best approach"
    ]

    /// Keywords that indicate simple queries
    private let simpleKeywords = [
        "what is", "who is", "when", "where", "define", "list",
        "hello", "hi", "thanks", "thank you", "yes", "no", "ok"
    ]

    /// Analyze a query and determine its complexity
    func analyze(query: String) -> Complexity {
        let lowercased = query.lowercased()
        let wordCount = query.split(separator: " ").count
        let questionCount = query.filter { $0 == "?" }.count
        let hasCodeBlock = query.contains("```") || query.contains("`")

        // Simple indicators
        if wordCount < 10 && simpleKeywords.contains(where: { lowercased.contains($0) }) {
            return .simple
        }

        // Complex indicators
        var complexityScore = 0

        // Length contributes to complexity
        if wordCount > 50 { complexityScore += 2 }
        else if wordCount > 25 { complexityScore += 1 }

        // Multiple questions
        if questionCount > 1 { complexityScore += 1 }

        // Code blocks present
        if hasCodeBlock { complexityScore += 2 }

        // Complex keywords
        for keyword in complexKeywords {
            if lowercased.contains(keyword) {
                complexityScore += 2
                break  // Count once even if multiple keywords match
            }
        }

        // Nested thoughts (contains "because", "therefore", "however")
        let reasoningWords = ["because", "therefore", "however", "although", "whereas", "consequently"]
        if reasoningWords.contains(where: { lowercased.contains($0) }) {
            complexityScore += 1
        }

        // Determine complexity level
        if complexityScore >= 4 {
            return .complex
        } else if complexityScore >= 2 {
            return .moderate
        } else {
            return .simple
        }
    }

    /// Check if thinking mode should be enabled for a query
    func shouldUseThinking(query: String, autoThinkingEnabled: Bool) -> Bool {
        guard autoThinkingEnabled else { return false }

        let complexity = analyze(query: query)
        return complexity == .complex
    }
}
