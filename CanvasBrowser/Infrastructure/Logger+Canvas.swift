import Foundation
import OSLog

/// Structured logging for Canvas Browser using OSLog
/// Replaces all print() statements with proper logging that persists in Console.app
extension Logger {
    /// App-wide events (lifecycle, state changes)
    static let app = Logger(subsystem: "com.canvas.browser", category: "app")
    
    /// Network requests and responses
    static let network = Logger(subsystem: "com.canvas.browser", category: "network")
    
    /// CoreData and persistence operations
    static let persistence = Logger(subsystem: "com.canvas.browser", category: "persistence")
    
    /// AI service interactions (Gemini, Claude, MCP)
    static let ai = Logger(subsystem: "com.canvas.browser", category: "ai")
    
    /// WebView and browser operations
    static let browser = Logger(subsystem: "com.canvas.browser", category: "browser")
    
    /// Security operations (keychain, passwords, authentication)
    static let security = Logger(subsystem: "com.canvas.browser", category: "security")
    
    /// UI events and interactions
    static let ui = Logger(subsystem: "com.canvas.browser", category: "ui")
}

/// Privacy-aware logging helpers
extension Logger {
    /// Log with automatic privacy redaction for sensitive data
    func debugSensitive(_ message: String, sensitive: String) {
        self.debug("\(message): \(sensitive, privacy: .private)")
    }
    
    /// Log error with context dictionary
    func errorWithContext(_ message: String, error: Error, context: [String: String] = [:]) {
        var contextString = ""
        if !context.isEmpty {
            contextString = " | Context: \(context.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))"
        }
        self.error("\(message): \(error.localizedDescription)\(contextString)")
    }
}
