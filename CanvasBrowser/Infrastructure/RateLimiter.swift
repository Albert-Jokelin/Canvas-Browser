import Foundation
import OSLog

/// Rate limiter to prevent excessive API usage
/// Tracks requests per endpoint and enforces limits
actor RateLimiter {
    static let shared = RateLimiter()
    
    private var requestCounts: [String: RequestWindow] = [:]
    
    private struct RequestWindow {
        var count: Int
        var resetTime: Date
    }
    
    enum RateLimitError: LocalizedError {
        case limitExceeded(endpoint: String, resetAt: Date)
        
        var errorDescription: String? {
            switch self {
            case .limitExceeded(let endpoint, let resetAt):
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                return "Rate limit exceeded for \(endpoint). Resets at \(formatter.string(from: resetAt))"
            }
        }
    }
    
    /// Check if request is allowed under rate limit
    /// - Parameters:
    ///   - endpoint: Endpoint identifier (e.g., "gemini.generateContent")
    ///   - limit: Maximum requests allowed in window
    ///   - window: Time window in seconds
    func checkLimit(for endpoint: String, limit: Int = 60, window: TimeInterval = 60) throws {
        let now = Date()
        
        if let existing = requestCounts[endpoint] {
            if now < existing.resetTime {
                // Within current window
                guard existing.count < limit else {
                    Logger.network.warning("Rate limit exceeded for \(endpoint)")
                    throw RateLimitError.limitExceeded(endpoint: endpoint, resetAt: existing.resetTime)
                }
                requestCounts[endpoint] = RequestWindow(
                    count: existing.count + 1,
                    resetTime: existing.resetTime
                )
            } else {
                // Window expired, start new window
                requestCounts[endpoint] = RequestWindow(
                    count: 1,
                    resetTime: now.addingTimeInterval(window)
                )
            }
        } else {
            // First request for this endpoint
            requestCounts[endpoint] = RequestWindow(
                count: 1,
                resetTime: now.addingTimeInterval(window)
            )
        }
        
        Logger.network.debug("Rate limit check passed for \(endpoint): \(self.requestCounts[endpoint]?.count ?? 0)/\(limit)")
    }
    
    /// Reset rate limit for endpoint (for testing or manual override)
    func reset(for endpoint: String) {
        requestCounts.removeValue(forKey: endpoint)
        Logger.network.info("Rate limit reset for \(endpoint)")
    }
    
    /// Reset all rate limits
    func resetAll() {
        requestCounts.removeAll()
        Logger.network.info("All rate limits reset")
    }
}
