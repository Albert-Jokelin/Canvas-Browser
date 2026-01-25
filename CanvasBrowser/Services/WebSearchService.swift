import Foundation

/// Service for performing web searches to provide current information to AI
class WebSearchService: ObservableObject {
    static let shared = WebSearchService()

    @Published var isSearching = false

    struct SearchResult: Codable, Identifiable {
        var id: String { url }
        let title: String
        let url: String
        let snippet: String
    }

    /// Keywords that indicate a query needs current/real-time information
    private let currentInfoKeywords = [
        "weather", "news", "today", "current", "latest", "now",
        "price", "stock", "score", "live", "happening", "recent",
        "update", "release", "announcement", "2024", "2025", "2026"
    ]

    /// Check if a query likely needs web search for current information
    func needsWebSearch(query: String) -> Bool {
        let lowercased = query.lowercased()
        return currentInfoKeywords.contains { lowercased.contains($0) }
    }

    /// Perform a web search using DuckDuckGo Instant Answer API
    func search(query: String, maxResults: Int = 5) async throws -> [SearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encodedQuery)&format=json&no_redirect=1&no_html=1") else {
            throw WebSearchError.invalidQuery
        }

        await MainActor.run { isSearching = true }
        defer {
            Task { @MainActor in isSearching = false }
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WebSearchError.requestFailed
        }

        // DuckDuckGo API response structure
        struct DDGResponse: Codable {
            let Abstract: String?
            let AbstractText: String?
            let AbstractSource: String?
            let AbstractURL: String?
            let Heading: String?
            let RelatedTopics: [RelatedTopic]?

            struct RelatedTopic: Codable {
                let Text: String?
                let FirstURL: String?
                let Result: String?
            }
        }

        let ddgResponse = try JSONDecoder().decode(DDGResponse.self, from: data)

        var results: [SearchResult] = []

        // Add abstract if available
        if let abstractText = ddgResponse.AbstractText, !abstractText.isEmpty,
           let abstractURL = ddgResponse.AbstractURL, !abstractURL.isEmpty,
           let heading = ddgResponse.Heading {
            results.append(SearchResult(
                title: heading,
                url: abstractURL,
                snippet: abstractText
            ))
        }

        // Add related topics
        if let topics = ddgResponse.RelatedTopics {
            for topic in topics.prefix(maxResults - results.count) {
                if let text = topic.Text, let url = topic.FirstURL, !url.isEmpty {
                    // Extract title from the HTML-like Result field or use first sentence
                    let title = text.components(separatedBy: " - ").first ?? text.prefix(50).description
                    results.append(SearchResult(
                        title: title,
                        url: url,
                        snippet: text
                    ))
                }
            }
        }

        return results
    }

    /// Format search results as context for AI
    func formatResultsAsContext(_ results: [SearchResult]) -> String {
        guard !results.isEmpty else {
            return ""
        }

        var context = "### Web Search Results\n\n"

        for (index, result) in results.enumerated() {
            context += """
            **[\(index + 1)] \(result.title)**
            URL: \(result.url)
            \(result.snippet)

            """
        }

        context += "\n---\nUse the above search results to provide accurate, current information.\n"

        return context
    }
}

enum WebSearchError: LocalizedError {
    case invalidQuery
    case requestFailed
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Invalid search query"
        case .requestFailed: return "Web search request failed"
        case .noResults: return "No search results found"
        }
    }
}
