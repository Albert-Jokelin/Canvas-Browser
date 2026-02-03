import Foundation
import Security
import Combine
import CommonCrypto
import OSLog

// MARK: - Saved Password Model

struct SavedPassword: Identifiable, Codable, Hashable {
    let id: UUID
    let domain: String
    let username: String
    let password: String
    let dateCreated: Date
    let dateModified: Date
    let notes: String?

    init(domain: String, username: String, password: String, notes: String? = nil) {
        self.id = UUID()
        self.domain = domain
        self.username = username
        self.password = password
        self.dateCreated = Date()
        self.dateModified = Date()
        self.notes = notes
    }

    var displayDomain: String {
        domain.replacingOccurrences(of: "www.", with: "")
    }

    var maskedPassword: String {
        String(repeating: "•", count: password.count)
    }
}

// MARK: - Password Manager

/// **DEPRECATED**: This custom password manager is deprecated in favor of native macOS Passwords app integration.
/// The app now uses system AutoFill which integrates with macOS Passwords app.
/// This class is kept for backward compatibility but is no longer actively used.
@available(*, deprecated, message: "Use native macOS Passwords app with AutoFill instead")
class PasswordManager: ObservableObject {
    static let shared = PasswordManager()

    @Published var savedPasswords: [SavedPassword] = []
    @Published var isUnlocked = false

    private let serviceName = "com.canvas.browser.passwords"

    // Notification names
    static let passwordSavedNotification = Notification.Name("CanvasPasswordSaved")
    static let passwordDeletedNotification = Notification.Name("CanvasPasswordDeleted")

    private init() {
        loadPasswords()
    }

    // MARK: - Save Password

    func savePassword(domain: String, username: String, password: String, notes: String? = nil) -> Bool {
        let savedPassword = SavedPassword(
            domain: domain,
            username: username,
            password: password,
            notes: notes
        )

        // Check if password already exists for this domain/username
        if let existingIndex = savedPasswords.firstIndex(where: { $0.domain == domain && $0.username == username }) {
            // Update existing
            if deleteFromKeychain(savedPasswords[existingIndex]) {
                savedPasswords.remove(at: existingIndex)
            }
        }

        // Save to keychain
        guard saveToKeychain(savedPassword) else {
            return false
        }

        savedPasswords.append(savedPassword)
        NotificationCenter.default.post(name: PasswordManager.passwordSavedNotification, object: nil)
        return true
    }

    // MARK: - Get Password

    func getPassword(for domain: String, username: String? = nil) -> SavedPassword? {
        if let username = username {
            return savedPasswords.first { $0.domain == domain && $0.username == username }
        }
        return savedPasswords.first { $0.domain == domain }
    }

    func getPasswords(for domain: String) -> [SavedPassword] {
        savedPasswords.filter { $0.domain.contains(domain) || domain.contains($0.domain) }
    }

    // MARK: - Delete Password

    func deletePassword(_ password: SavedPassword) -> Bool {
        guard deleteFromKeychain(password) else {
            return false
        }

        if let index = savedPasswords.firstIndex(of: password) {
            savedPasswords.remove(at: index)
        }

        NotificationCenter.default.post(name: PasswordManager.passwordDeletedNotification, object: nil)
        return true
    }

    func deleteAllPasswords() -> Bool {
        for password in savedPasswords {
            _ = deleteFromKeychain(password)
        }
        savedPasswords.removeAll()
        return true
    }

    // MARK: - Search

    func search(query: String) -> [SavedPassword] {
        guard !query.isEmpty else { return savedPasswords }

        let lowercasedQuery = query.lowercased()
        return savedPasswords.filter {
            $0.domain.lowercased().contains(lowercasedQuery) ||
            $0.username.lowercased().contains(lowercasedQuery) ||
            ($0.notes?.lowercased().contains(lowercasedQuery) ?? false)
        }
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(_ password: SavedPassword) -> Bool {
        guard let passwordData = try? JSONEncoder().encode(password) else {
            return false
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(password.domain):\(password.username)",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // First try to delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func deleteFromKeychain(_ password: SavedPassword) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "\(password.domain):\(password.username)"
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func loadPasswords() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            savedPasswords = []
            return
        }

        savedPasswords = items.compactMap { item in
            guard let data = item[kSecValueData as String] as? Data,
                  let password = try? JSONDecoder().decode(SavedPassword.self, from: data) else {
                return nil
            }
            return password
        }
    }

    // MARK: - Password Generation

    static func generatePassword(length: Int = 16, includeSymbols: Bool = true) -> String {
        var characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        if includeSymbols {
            characters += "!@#$%^&*()-_=+[]{}|;:,.<>?"
        }

        var password = ""
        for _ in 0..<length {
            if let char = characters.randomElement() {
                password.append(char)
            }
        }

        return password
    }

    static func evaluatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0

        // Length
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }

        // Character types
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 1 }

        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .veryStrong
        }
    }

    // MARK: - Authentication

    private let masterPasswordKey = "canvas_master_password_hash"

    /// Set up master password for the first time
    func setupMasterPassword(_ password: String) -> Bool {
        guard !password.isEmpty else { return false }

        // Hash the password using SHA-256
        guard let hash = hashPassword(password) else { return false }

        // Store the hash in Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: masterPasswordKey,
            kSecValueData as String: hash.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete existing if any
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Check if master password has been set up
    var isMasterPasswordSetup: Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: masterPasswordKey,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Unlock with master password validation
    func unlock(with password: String) -> Bool {
        // If no master password is set, set it up with the provided password
        if !isMasterPasswordSetup {
            if setupMasterPassword(password) {
                isUnlocked = true
                return true
            }
            return false
        }

        // Retrieve stored hash
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: masterPasswordKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let hashData = result as? Data,
              let storedHash = String(data: hashData, encoding: .utf8) else {
            Logger.security.warning("Failed to retrieve master password hash")
            return false
        }

        // Verify password using PBKDF2
        let isValid = verifyPassword(password, against: storedHash)

        if isValid {
            isUnlocked = true
        }

        return isValid
    }

    func lock() {
        isUnlocked = false
    }

    /// Hash password using PBKDF2 with salt (OWASP recommended)
    /// - Parameter password: Plain text password
    /// - Returns: Base64-encoded salt + hash (16 bytes salt + 32 bytes hash)
    private func hashPassword(_ password: String) -> String? {
        guard let data = password.data(using: .utf8) else {
            Logger.security.error("Failed to convert password to UTF-8")
            return nil
        }

        // Generate random salt (16 bytes)
        var salt = Data(count: 16)
        let saltResult = salt.withUnsafeMutableBytes { saltBytes in
            SecRandomCopyBytes(kSecRandomDefault, 16, saltBytes.baseAddress!)
        }

        guard saltResult == errSecSuccess else {
            Logger.security.error("Failed to generate salt for password hashing")
            CrashReporter.shared.recordError(
                SecurityError.keychainSaveFailed(status: saltResult),
                context: ["operation": "generateSalt"]
            )
            return nil
        }

        // Use PBKDF2 with 100,000 iterations (OWASP recommendation for 2024)
        let iterations = 100_000
        let keyLength = 32

        var derivedKey = Data(count: keyLength)
        let derivationStatus = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                data.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self),
                        data.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            Logger.security.error("Password derivation failed with status: \(derivationStatus)")
            return nil
        }

        // Store salt + hash together (16 + 32 = 48 bytes)
        let combined = salt + derivedKey
        Logger.security.debug("Password hashed successfully with PBKDF2")
        return combined.base64EncodedString()
    }

    /// Verify password against stored hash
    /// - Parameters:
    ///   - password: Plain text password to verify
    ///   - storedHash: Base64-encoded salt + hash from storage
    /// - Returns: True if password matches
    private func verifyPassword(_ password: String, against storedHash: String) -> Bool {
        guard let combined = Data(base64Encoded: storedHash),
              combined.count >= 48 else { // 16 bytes salt + 32 bytes hash
            Logger.security.error("Invalid stored hash format")
            return false
        }

        let salt = combined.prefix(16)
        let storedKey = combined.suffix(32)

        // Derive key with same salt
        guard let data = password.data(using: .utf8) else {
            Logger.security.error("Failed to convert password to UTF-8")
            return false
        }

        var derivedKey = Data(count: 32)
        let derivationStatus = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                data.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress!.assumingMemoryBound(to: Int8.self),
                        data.count,
                        saltBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100_000,
                        derivedKeyBytes.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard derivationStatus == kCCSuccess else {
            Logger.security.error("Password verification derivation failed")
            return false
        }

        // Constant-time comparison
        return secureCompare(derivedKey, storedKey)
    }

    /// Constant-time Data comparison to prevent timing attacks
    private func secureCompare(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }

        var result: UInt8 = 0
        for (byte1, byte2) in zip(a, b) {
            result |= byte1 ^ byte2
        }

        return result == 0
    }
}

// MARK: - Password Strength

enum PasswordStrength: String {
    case weak = "Weak"
    case medium = "Medium"
    case strong = "Strong"
    case veryStrong = "Very Strong"

    var color: Color {
        switch self {
        case .weak: return .canvasRed
        case .medium: return .canvasOrange
        case .strong: return .canvasGreen
        case .veryStrong: return .canvasBlue
        }
    }

    var progress: Double {
        switch self {
        case .weak: return 0.25
        case .medium: return 0.5
        case .strong: return 0.75
        case .veryStrong: return 1.0
        }
    }
}

// MARK: - Import for Color

import SwiftUI
