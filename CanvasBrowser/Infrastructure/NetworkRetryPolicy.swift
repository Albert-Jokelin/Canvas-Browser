import Foundation
import OSLog

/// Network retry policy with exponential backoff
/// Handles transient failures gracefully
struct NetworkRetryPolicy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    
    init(maxRetries: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }
    
    /// Execute operation with retry logic
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch let error as URLError {
                lastError = error
                
                // Don't retry on certain errors
                guard shouldRetry(error) else {
                    Logger.network.error("Non-retryable error: \(error.localizedDescription)")
                    throw error
                }
                
                // Exponential backoff
                let delay = min(baseDelay * pow(2.0, Double(attempt)), maxDelay)
                Logger.network.info("Retry attempt \(attempt + 1)/\(maxRetries) after \(delay)s")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch let error as NetworkError {
                lastError = error
                
                // Handle rate limiting specially
                if case .rateLimited(let retryAfter) = error {
                    Logger.network.warning("Rate limited, waiting \(retryAfter)s")
                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    continue
                }
                
                throw error
                
            } catch {
                // Non-network errors fail immediately
                Logger.network.error("Non-network error: \(error.localizedDescription)")
                throw error
            }
        }
        
        Logger.network.error("Max retries exceeded")
        throw lastError ?? NetworkError.maxRetriesExceeded
    }
    
    private func shouldRetry(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
            return true
        default:
            return false
        }
    }
}

enum NetworkError: LocalizedError {
    case maxRetriesExceeded
    case rateLimited(retryAfter: TimeInterval)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .rateLimited(let seconds):
            return "Rate limited, retry after \(seconds) seconds"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}
