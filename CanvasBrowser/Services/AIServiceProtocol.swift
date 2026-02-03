import Foundation

/// Protocol defining the common interface for AI service providers
/// Enables switching between Gemini, Claude, or other providers
@MainActor
protocol AIServiceProtocol: AnyObject {
    /// The API key for authentication
    var apiKey: String { get set }

    /// Generate a text response for a given prompt
    func generateResponse(prompt: String) async throws -> String

    /// Build a GenTab from a natural language prompt
    func buildGenTab(for prompt: String, sourceURLs: [SourceAttribution]) async throws -> GenTab
}

/// Errors that can occur across AI services
enum AIServiceError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case missingAPIKey
    case invalidJSONResponse
    case apiError(String)
    case providerNotConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for API request"
        case .noData:
            return "No data received from API"
        case .decodingError:
            return "Failed to parse API response"
        case .missingAPIKey:
            return "API key is not configured. Please add it in Settings."
        case .invalidJSONResponse:
            return "Invalid JSON response from API"
        case .apiError(let message):
            return "API error: \(message)"
        case .providerNotConfigured:
            return "AI provider is not configured"
        }
    }
}
