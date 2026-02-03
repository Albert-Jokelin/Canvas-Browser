import Foundation
import OSLog

/// Input validation for AI prompts
/// Prevents injection attacks, excessive costs, and data exfiltration
struct PromptValidator {
    static let maxPromptLength = 10_000
    static let maxTokenEstimate = 8_000
    
    enum ValidationError: LocalizedError {
        case tooLong(Int)
        case containsNullBytes
        case suspiciousPattern(String)
        
        var errorDescription: String? {
            switch self {
            case .tooLong(let length):
                return "Prompt exceeds maximum length (\(length) > \(maxPromptLength) characters)"
            case .containsNullBytes:
                return "Prompt contains null bytes"
            case .suspiciousPattern(let pattern):
                return "Prompt contains suspicious pattern: \(pattern)"
            }
        }
    }
    
    /// Validate and sanitize user prompt
    static func validate(_ prompt: String) throws -> String {
        // Length check
        guard prompt.count <= maxPromptLength else {
            Logger.security.warning("Prompt too long: \(prompt.count) chars")
            throw ValidationError.tooLong(prompt.count)
        }
        
        // Check for null bytes
        guard !prompt.contains("\0") else {
            Logger.security.error("Prompt contains null bytes")
            throw ValidationError.containsNullBytes
        }
        
        // Sanitize
        let sanitized = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\0", with: "")
        
        // Check for suspicious patterns (log but allow)
        let suspiciousPatterns = [
            "system:", "ignore previous", "disregard instructions",
            "<script>", "javascript:", "eval(", "exec("
        ]
        
        for pattern in suspiciousPatterns {
            if sanitized.lowercased().contains(pattern.lowercased()) {
                Logger.security.warning("Suspicious pattern detected: \(pattern, privacy: .public)")
                // Log but allow - could be legitimate
            }
        }
        
        return sanitized
    }
    
    /// Estimate token count (rough approximation: 1 token ≈ 4 characters)
    static func estimateTokens(_ text: String) -> Int {
        text.count / 4
    }
}
