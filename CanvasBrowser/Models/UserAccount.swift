import Foundation
import SwiftUI

class UserAccount: ObservableObject {
    @Published var name: String = "User"
    @Published var email: String = "user@example.com"
    @Published var profileImageURL: URL? = nil
    
    @Published var syncHistory: Bool = true
    @Published var syncBookmarks: Bool = true
    @Published var syncGenTabs: Bool = true
    
    @Published var cacheSize: String = "120 MB"
    
    // Mock user for now
    static let shared = UserAccount()
}
