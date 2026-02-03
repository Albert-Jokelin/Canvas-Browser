import Foundation
import OSLog

/// Shared JSON response parser to eliminate code duplication
/// Handles markdown-wrapped JSON and provides consistent error handling
struct JSONResponseParser {
    enum ParsingError: LocalizedError {
        case invalidJSON(String)
        case decodingFailed(Error, preview: String)
        
        var errorDescription: String? {
            switch self {
            case .invalidJSON(let reason):
                return "Invalid JSON in response: \(reason)"
            case .decodingFailed(let error, let preview):
                return "Failed to decode JSON: \(error.localizedDescription). Preview: \(preview)"
            }
        }
    }
    
    /// Clean markdown code blocks from JSON response
    static func cleanMarkdownJSON(_ response: String) -> String {
        response
            .replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Decode JSON response to specified type
    static func decode<T: Decodable>(_ type: T.Type, from response: String) throws -> T {
        let cleaned = cleanMarkdownJSON(response)
        
        guard let data = cleaned.data(using: .utf8) else {
            Logger.network.error("Failed to convert response to UTF-8 data")
            throw ParsingError.invalidJSON("Could not convert to UTF-8")
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            let preview = String(cleaned.prefix(500))
            Logger.network.error("JSON decode error: \(error.localizedDescription)")
            Logger.network.debug("Response preview: \(preview)")
            throw ParsingError.decodingFailed(error, preview: preview)
        }
    }
    
    /// Parse JSON from Data
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "Unable to preview"
            Logger.network.error("JSON decode error: \(error.localizedDescription)")
            Logger.network.debug("Data preview: \(preview)")
            throw ParsingError.decodingFailed(error, preview: preview)
        }
    }
}
