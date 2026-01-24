import Foundation
import SwiftUI

/// Represents a group of tabs that can be organized together
struct TabGroup: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var colorName: String
    var tabIds: [UUID]
    var isCollapsed: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        colorName: String = "blue",
        tabIds: [UUID] = [],
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.tabIds = tabIds
        self.isCollapsed = isCollapsed
        self.createdAt = Date()
    }

    /// Get the SwiftUI Color from the stored color name
    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "gray": return .gray
        default: return .blue
        }
    }

    /// Available colors for tab groups
    static let availableColors = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]

    /// Available icons for tab groups
    static let availableIcons = [
        "folder.fill", "star.fill", "heart.fill", "bookmark.fill",
        "tag.fill", "flag.fill", "bolt.fill", "leaf.fill",
        "briefcase.fill", "graduationcap.fill", "cart.fill", "house.fill",
        "airplane", "car.fill", "gamecontroller.fill", "music.note"
    ]
}

// MARK: - Tab Group Manager

class TabGroupManager: ObservableObject {
    @Published var groups: [TabGroup] = []

    private let saveKey = "savedTabGroups"

    init() {
        loadGroups()
    }

    // MARK: - CRUD Operations

    /// Create a new tab group
    @discardableResult
    func createGroup(name: String, tabIds: [UUID] = [], icon: String = "folder.fill", colorName: String = "blue") -> TabGroup {
        let group = TabGroup(name: name, icon: icon, colorName: colorName, tabIds: tabIds)
        groups.append(group)
        saveGroups()
        return group
    }

    /// Delete a tab group (tabs remain, just ungrouped)
    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        saveGroups()
    }

    /// Rename a tab group
    func renameGroup(id: UUID, newName: String) {
        if let index = groups.firstIndex(where: { $0.id == id }) {
            groups[index].name = newName
            saveGroups()
        }
    }

    /// Update group icon
    func updateGroupIcon(id: UUID, icon: String) {
        if let index = groups.firstIndex(where: { $0.id == id }) {
            groups[index].icon = icon
            saveGroups()
        }
    }

    /// Update group color
    func updateGroupColor(id: UUID, colorName: String) {
        if let index = groups.firstIndex(where: { $0.id == id }) {
            groups[index].colorName = colorName
            saveGroups()
        }
    }

    // MARK: - Tab Management

    /// Add a tab to a group
    func addTabToGroup(tabId: UUID, groupId: UUID) {
        // Remove from any existing group first
        removeTabFromAllGroups(tabId: tabId)

        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].tabIds.append(tabId)
            saveGroups()
        }
    }

    /// Add multiple tabs to a group
    func addTabsToGroup(tabIds: [UUID], groupId: UUID) {
        for tabId in tabIds {
            addTabToGroup(tabId: tabId, groupId: groupId)
        }
    }

    /// Remove a tab from a specific group
    func removeTabFromGroup(tabId: UUID, groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].tabIds.removeAll { $0 == tabId }
            saveGroups()
        }
    }

    /// Remove a tab from all groups
    func removeTabFromAllGroups(tabId: UUID) {
        for index in groups.indices {
            groups[index].tabIds.removeAll { $0 == tabId }
        }
        saveGroups()
    }

    /// Get the group that contains a specific tab
    func groupForTab(tabId: UUID) -> TabGroup? {
        groups.first { $0.tabIds.contains(tabId) }
    }

    /// Check if a tab is in any group
    func isTabGrouped(tabId: UUID) -> Bool {
        groups.contains { $0.tabIds.contains(tabId) }
    }

    /// Get all ungrouped tab IDs from a list of tabs
    func getUngroupedTabIds(from allTabIds: [UUID]) -> [UUID] {
        let groupedTabIds = Set(groups.flatMap { $0.tabIds })
        return allTabIds.filter { !groupedTabIds.contains($0) }
    }

    // MARK: - Collapse/Expand

    /// Toggle collapse state of a group
    func toggleCollapsed(groupId: UUID) {
        if let index = groups.firstIndex(where: { $0.id == groupId }) {
            groups[index].isCollapsed.toggle()
            saveGroups()
        }
    }

    /// Collapse all groups
    func collapseAll() {
        for index in groups.indices {
            groups[index].isCollapsed = true
        }
        saveGroups()
    }

    /// Expand all groups
    func expandAll() {
        for index in groups.indices {
            groups[index].isCollapsed = false
        }
        saveGroups()
    }

    // MARK: - Persistence

    func saveGroups() {
        do {
            let data = try JSONEncoder().encode(groups)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to save tab groups: \(error)")
        }
    }

    func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        do {
            groups = try JSONDecoder().decode([TabGroup].self, from: data)
        } catch {
            print("Failed to load tab groups: \(error)")
        }
    }

    /// Clean up groups by removing references to tabs that no longer exist
    func cleanupGroups(existingTabIds: Set<UUID>) {
        var needsSave = false
        for index in groups.indices {
            let originalCount = groups[index].tabIds.count
            groups[index].tabIds = groups[index].tabIds.filter { existingTabIds.contains($0) }
            if groups[index].tabIds.count != originalCount {
                needsSave = true
            }
        }
        if needsSave {
            saveGroups()
        }
    }
}
