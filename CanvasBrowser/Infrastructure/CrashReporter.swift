import Foundation
import OSLog

/// Protocol for crash reporting integration
/// Allows swapping implementations (Sentry, Crashlytics, etc.) without changing call sites
protocol CrashReporting {
    func recordError(_ error: Error, context: [String: String])
    func recordFatalError(_ error: Error, context: [String: String])
    func setUserContext(_ userId: String?, email: String?)
    func addBreadcrumb(_ message: String, category: String, level: BreadcrumbLevel)
}

enum BreadcrumbLevel: String {
    case debug, info, warning, error
}

/// Stub implementation that logs to OSLog
/// Replace with actual crash reporting service (Sentry, Crashlytics) in production
final class StubCrashReporter: CrashReporting {
    static let shared: CrashReporting = StubCrashReporter()
    
    private init() {}
    
    func recordError(_ error: Error, context: [String: String]) {
        Logger.app.error("Error recorded: \(error.localizedDescription)")
        if !context.isEmpty {
            Logger.app.debug("Context: \(context.description)")
        }
    }
    
    func recordFatalError(_ error: Error, context: [String: String]) {
        Logger.app.critical("Fatal error: \(error.localizedDescription)")
        if !context.isEmpty {
            Logger.app.critical("Context: \(context.description)")
        }
    }
    
    func setUserContext(_ userId: String?, email: String?) {
        Logger.app.debug("User context set: userId=\(userId ?? "nil", privacy: .private)")
    }
    
    func addBreadcrumb(_ message: String, category: String, level: BreadcrumbLevel) {
        Logger.app.debug("[\(category)] \(message)")
    }
}

/// Global accessor for crash reporter
/// Usage: CrashReporter.shared.recordError(error, context: ["operation": "fetchData"])
typealias CrashReporter = StubCrashReporter
