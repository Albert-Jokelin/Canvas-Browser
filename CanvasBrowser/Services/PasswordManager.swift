import Foundation
import Security
import Combine

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

    func unlock(with password: String) -> Bool {
        // In a real implementation, this would verify against a master password
        // For now, we just set unlocked to true
        isUnlocked = true
        return true
    }

    func lock() {
        isUnlocked = false
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
