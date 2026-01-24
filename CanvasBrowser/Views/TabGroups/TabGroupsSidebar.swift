import SwiftUI

/// Sidebar view for managing tab groups
struct TabGroupsSidebar: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var groupManager: TabGroupManager
    @Binding var selectedTabId: UUID?

    @State private var isCreatingGroup = false
    @State private var newGroupName = ""
    @State private var editingGroupId: UUID?
    @State private var draggedTabId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tab Groups")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { isCreatingGroup = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .help("Create new tab group")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Groups list
            ScrollView {
                LazyVStack(spacing: 4) {
                    // Tab Groups
                    ForEach(groupManager.groups) { group in
                        TabGroupRow(
                            group: group,
                            tabs: tabsInGroup(group),
                            selectedTabId: $selectedTabId,
                            isEditing: editingGroupId == group.id,
                            onToggleCollapse: {
                                groupManager.toggleCollapsed(groupId: group.id)
                            },
                            onRename: { newName in
                                groupManager.renameGroup(id: group.id, newName: newName)
                                editingGroupId = nil
                            },
                            onDelete: {
                                groupManager.deleteGroup(id: group.id)
                            },
                            onTabSelect: { tabId in
                                selectedTabId = tabId
                                appState.sessionManager.currentTabId = tabId
                            },
                            onTabRemove: { tabId in
                                groupManager.removeTabFromGroup(tabId: tabId, groupId: group.id)
                            },
                            onTabClose: { tabId in
                                appState.sessionManager.closeTab(id: tabId)
                            }
                        )
                        .contextMenu {
                            Button("Rename") {
                                editingGroupId = group.id
                            }

                            Menu("Change Color") {
                                ForEach(TabGroup.availableColors, id: \.self) { color in
                                    Button(action: {
                                        groupManager.updateGroupColor(id: group.id, colorName: color)
                                    }) {
                                        Label(color.capitalized, systemImage: "circle.fill")
                                    }
                                }
                            }

                            Menu("Change Icon") {
                                ForEach(TabGroup.availableIcons, id: \.self) { icon in
                                    Button(action: {
                                        groupManager.updateGroupIcon(id: group.id, icon: icon)
                                    }) {
                                        Label(icon, systemImage: icon)
                                    }
                                }
                            }

                            Divider()

                            Button("Delete Group", role: .destructive) {
                                groupManager.deleteGroup(id: group.id)
                            }
                        }
                    }

                    // Ungrouped tabs section
                    let ungroupedTabs = getUngroupedTabs()
                    if !ungroupedTabs.isEmpty {
                        UngroupedTabsSection(
                            tabs: ungroupedTabs,
                            selectedTabId: $selectedTabId,
                            onTabSelect: { tabId in
                                selectedTabId = tabId
                                appState.sessionManager.currentTabId = tabId
                            },
                            onAddToGroup: { tabId, groupId in
                                groupManager.addTabToGroup(tabId: tabId, groupId: groupId)
                            },
                            availableGroups: groupManager.groups
                        )
                    }
                }
                .padding(8)
            }
        }
        .sheet(isPresented: $isCreatingGroup) {
            CreateTabGroupSheet(
                groupManager: groupManager,
                availableTabs: appState.sessionManager.activeTabs,
                isPresented: $isCreatingGroup
            )
        }
    }

    private func tabsInGroup(_ group: TabGroup) -> [BrowsingSession.TabItem] {
        group.tabIds.compactMap { tabId in
            appState.sessionManager.activeTabs.first { $0.id == tabId }
        }
    }

    private func getUngroupedTabs() -> [BrowsingSession.TabItem] {
        let allTabIds = appState.sessionManager.activeTabs.map { $0.id }
        let ungroupedIds = groupManager.getUngroupedTabIds(from: allTabIds)
        return appState.sessionManager.activeTabs.filter { ungroupedIds.contains($0.id) }
    }
}

// MARK: - Tab Group Row

struct TabGroupRow: View {
    let group: TabGroup
    let tabs: [BrowsingSession.TabItem]
    @Binding var selectedTabId: UUID?
    let isEditing: Bool
    let onToggleCollapse: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onTabSelect: (UUID) -> Void
    let onTabRemove: (UUID) -> Void
    var onTabClose: ((UUID) -> Void)?

    @State private var editedName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack(spacing: 8) {
                Button(action: onToggleCollapse) {
                    Image(systemName: group.isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: group.icon)
                    .foregroundColor(group.color)
                    .font(.system(size: 14))

                if isEditing {
                    TextField("Group Name", text: $editedName, onCommit: {
                        onRename(editedName)
                    })
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .onAppear { editedName = group.name }
                } else {
                    Text(group.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("\(tabs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)

            // Tabs in group (when expanded)
            if !group.isCollapsed {
                VStack(spacing: 2) {
                    ForEach(tabs) { tab in
                        TabRowInGroup(
                            tab: tab,
                            isSelected: selectedTabId == tab.id,
                            groupColor: group.color,
                            onSelect: { onTabSelect(tab.id) },
                            onRemove: { onTabRemove(tab.id) },
                            onClose: onTabClose != nil ? { onTabClose?(tab.id) } : nil
                        )
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Tab Row in Group

struct TabRowInGroup: View {
    let tab: BrowsingSession.TabItem
    let isSelected: Bool
    let groupColor: Color
    let onSelect: () -> Void
    let onRemove: () -> Void
    var onClose: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(groupColor)
                .frame(width: 3, height: 16)

            // Tab icon
            Image(systemName: tabIcon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            // Tab title
            Text(tab.title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Buttons on hover
            if isHovered {
                // Close tab button
                if let onClose = onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close tab")
                }

                // Remove from group button
                Button(action: onRemove) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove from group")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var tabIcon: String {
        switch tab {
        case .web: return "globe"
        case .gen: return "sparkles"
        }
    }
}

// MARK: - Ungrouped Tabs Section

struct UngroupedTabsSection: View {
    let tabs: [BrowsingSession.TabItem]
    @Binding var selectedTabId: UUID?
    let onTabSelect: (UUID) -> Void
    let onAddToGroup: (UUID, UUID) -> Void
    let availableGroups: [TabGroup]

    @State private var isCollapsed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Button(action: { isCollapsed.toggle() }) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)

                Image(systemName: "tray")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                Text("Ungrouped")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(tabs.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)

            // Ungrouped tabs
            if !isCollapsed {
                VStack(spacing: 2) {
                    ForEach(tabs) { tab in
                        UngroupedTabRow(
                            tab: tab,
                            isSelected: selectedTabId == tab.id,
                            onSelect: { onTabSelect(tab.id) },
                            onAddToGroup: { groupId in onAddToGroup(tab.id, groupId) },
                            availableGroups: availableGroups
                        )
                    }
                }
                .padding(.leading, 20)
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Ungrouped Tab Row

struct UngroupedTabRow: View {
    let tab: BrowsingSession.TabItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onAddToGroup: (UUID) -> Void
    let availableGroups: [TabGroup]

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: tabIcon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(tab.title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if isHovered && !availableGroups.isEmpty {
                Menu {
                    ForEach(availableGroups) { group in
                        Button(action: { onAddToGroup(group.id) }) {
                            Label(group.name, systemImage: group.icon)
                        }
                    }
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .help("Add to group")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onSelect)
    }

    private var tabIcon: String {
        switch tab {
        case .web: return "globe"
        case .gen: return "sparkles"
        }
    }
}

// MARK: - Create Tab Group Sheet

struct CreateTabGroupSheet: View {
    @ObservedObject var groupManager: TabGroupManager
    let availableTabs: [BrowsingSession.TabItem]
    @Binding var isPresented: Bool

    @State private var groupName = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "blue"
    @State private var selectedTabIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Create Tab Group")
                .font(.headline)

            // Group name
            TextField("Group Name", text: $groupName)
                .textFieldStyle(.roundedBorder)

            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    ForEach(TabGroup.availableColors, id: \.self) { color in
                        Circle()
                            .fill(colorFor(color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                            )
                            .onTapGesture { selectedColor = color }
                    }
                }
            }

            // Icon picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 8), spacing: 8) {
                    ForEach(TabGroup.availableIcons, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(selectedIcon == icon ? colorFor(selectedColor) : .secondary)
                            .frame(width: 28, height: 28)
                            .background(selectedIcon == icon ? colorFor(selectedColor).opacity(0.2) : Color.clear)
                            .cornerRadius(4)
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            // Tab selection
            if !availableTabs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Tabs (Optional)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(availableTabs) { tab in
                                HStack {
                                    Image(systemName: selectedTabIds.contains(tab.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedTabIds.contains(tab.id) ? colorFor(selectedColor) : .secondary)

                                    Text(tab.title)
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedTabIds.contains(tab.id) {
                                        selectedTabIds.remove(tab.id)
                                    } else {
                                        selectedTabIds.insert(tab.id)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    groupManager.createGroup(
                        name: groupName.isEmpty ? "New Group" : groupName,
                        tabIds: Array(selectedTabIds),
                        icon: selectedIcon,
                        colorName: selectedColor
                    )
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(groupName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 350)
    }

    private func colorFor(_ name: String) -> Color {
        switch name {
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
}

// MARK: - Preview

#if DEBUG
struct TabGroupsSidebar_Previews: PreviewProvider {
    static var previews: some View {
        TabGroupsSidebar(
            groupManager: TabGroupManager(),
            selectedTabId: .constant(nil)
        )
        .frame(width: 280, height: 500)
        .environmentObject(AppState())
    }
}
#endif
