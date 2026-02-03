import Foundation

/// Comprehensive error types for Canvas Browser
/// Provides context, recovery suggestions, and proper error propagation

// NOTE: AIServiceError is defined in AIServiceProtocol.swift

// MARK: - Persistence Errors

enum PersistenceError: LocalizedError {
    case saveFailed(entity: String, underlying: Error)
    case fetchFailed(entity: String, underlying: Error)
    case deleteFailed(entity: String, underlying: Error)
    case migrationFailed(underlying: Error)
    case corruptedStore(url: URL)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let entity, let error):
            return "Failed to save \(entity): \(error.localizedDescription)"
        case .fetchFailed(let entity, let error):
            return "Failed to fetch \(entity): \(error.localizedDescription)"
        case .deleteFailed(let entity, let error):
            return "Failed to delete \(entity): \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Database migration failed: \(error.localizedDescription)"
        case .corruptedStore(let url):
            return "Database is corrupted at \(url.path)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .fetchFailed, .deleteFailed:
            return "Try again. If the problem persists, restart the app."
        case .migrationFailed:
            return "Your data may need to be reset. Contact support for assistance."
        case .corruptedStore:
            return "The database will be recreated. Recent data may be lost."
        }
    }
}

// MARK: - Security Errors

enum SecurityError: LocalizedError {
    case keychainAccessDenied
    case keychainSaveFailed(status: OSStatus)
    case keychainRetrieveFailed(status: OSStatus)
    case invalidCredentials
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .keychainAccessDenied:
            return "Access to Keychain was denied"
        case .keychainSaveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .keychainRetrieveFailed(let status):
            return "Failed to retrieve from Keychain (status: \(status))"
        case .invalidCredentials:
            return "Invalid credentials provided"
        case .authenticationFailed:
            return "Authentication failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .keychainAccessDenied:
            return "Grant Keychain access in System Settings > Privacy & Security"
        case .keychainSaveFailed, .keychainRetrieveFailed:
            return "Try restarting the app. If the problem persists, reset your Keychain."
        case .invalidCredentials:
            return "Check your credentials and try again."
        case .authenticationFailed:
            return "Verify your password and try again."
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case invalidInput(field: String, reason: String)
    case missingRequiredField(field: String)
    case invalidFormat(field: String, expected: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .missingRequiredField(let field):
            return "Required field missing: \(field)"
        case .invalidFormat(let field, let expected):
            return "Invalid format for \(field). Expected: \(expected)"
        }
    }
}
