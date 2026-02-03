import Foundation
import OSLog

/// Secure string wrapper that zeros memory on deallocation
/// Use for sensitive data like API keys, passwords, tokens
final class SecureString {
    private var data: Data
    
    /// Create secure string from plain string
    init(_ string: String) {
        self.data = string.data(using: .utf8) ?? Data()
    }
    
    /// Get the string value (use sparingly, only when needed)
    var value: String {
        String(data: data, encoding: .utf8) ?? ""
    }
    
    /// Check if empty without exposing value
    var isEmpty: Bool {
        data.isEmpty
    }
    
    /// Get length without exposing value
    var count: Int {
        data.count
    }
    
    deinit {
        // Zero out memory before deallocation to prevent memory dumps
        data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            memset(baseAddress, 0, bytes.count)
        }
        Logger.security.debug("SecureString memory zeroed")
    }
}

/// Secure storage for API keys with on-demand loading
final class SecureAPIKeyStore {
    private var geminiKey: SecureString?
    private var claudeKey: SecureString?
    
    /// Set Gemini API key (stores in memory and UserDefaults)
    func setGeminiKey(_ key: String) {
        geminiKey = SecureString(key)
        UserDefaults.standard.set(key, forKey: "geminiApiKey")
        Logger.security.debug("Gemini API key stored")
    }
    
    /// Set Claude API key (stores in memory and UserDefaults)
    func setClaudeKey(_ key: String) {
        claudeKey = SecureString(key)
        UserDefaults.standard.set(key, forKey: "claudeApiKey")
        Logger.security.debug("Claude API key stored")
    }
    
    /// Get Gemini API key (loads from UserDefaults if not in memory)
    func getGeminiKey() throws -> String {
        if let key = geminiKey {
            return key.value
        }
        
        // Load from UserDefaults
        if let stored = UserDefaults.standard.string(forKey: "geminiApiKey") {
            geminiKey = SecureString(stored)
            return stored
        }
        
        throw APIKeyError.missingKey("Gemini API key not configured")
    }
    
    /// Get Claude API key (loads from UserDefaults if not in memory)
    func getClaudeKey() throws -> String {
        if let key = claudeKey {
            return key.value
        }
        
        // Load from UserDefaults
        if let stored = UserDefaults.standard.string(forKey: "claudeApiKey") {
            claudeKey = SecureString(stored)
            return stored
        }
        
        throw APIKeyError.missingKey("Claude API key not configured")
    }
    
    /// Check if Gemini key exists without loading it
    var hasGeminiKey: Bool {
        geminiKey != nil || UserDefaults.standard.string(forKey: "geminiApiKey") != nil
    }
    
    /// Check if Claude key exists without loading it
    var hasClaudeKey: Bool {
        geminiKey != nil || UserDefaults.standard.string(forKey: "claudeApiKey") != nil
    }
    
    /// Clear all keys from memory (still in UserDefaults)
    func clearMemory() {
        geminiKey = nil
        claudeKey = nil
        Logger.security.debug("API keys cleared from memory")
    }
}

enum APIKeyError: LocalizedError {
    case missingKey(String)
    
    var errorDescription: String? {
        switch self {
        case .missingKey(let message):
            return message
        }
    }
}
