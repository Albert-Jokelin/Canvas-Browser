import SwiftUI

/// A dynamic shelf view that displays categorized content in a horizontal scrollable layout
struct DynamicShelfView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: ShelfCategory = .genTabs

    enum ShelfCategory: String, CaseIterable {
        case genTabs = "GenTabs"
        case bookmarks = "Bookmarks"
        case readingList = "Reading List"
        case history = "History"

        var icon: String {
            switch self {
            case .genTabs: return "sparkles.rectangle.stack"
            case .bookmarks: return "bookmark.fill"
            case .readingList: return "eyeglasses"
            case .history: return "clock.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            HStack(spacing: 4) {
                ForEach(ShelfCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            // Content area
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    switch selectedCategory {
                    case .genTabs:
                        genTabsContent
                    case .bookmarks:
                        bookmarksContent
                    case .readingList:
                        readingListContent
                    case .history:
                        historyContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(height: 120)
        }
        .frame(height: 170)
        .background(.ultraThinMaterial)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var genTabsContent: some View {
        let genTabs = appState.sessionManager.tabs.compactMap { tab -> GenTab? in
            if case .gen(let genTab) = tab { return genTab }
            return nil
        }

        if genTabs.isEmpty {
            emptyState(message: "No GenTabs yet", icon: "sparkles")
        } else {
            ForEach(genTabs) { genTab in
                ShelfItemCard(
                    title: genTab.title,
                    subtitle: "\(genTab.components.count) components",
                    icon: genTab.icon,
                    color: .purple
                ) {
                    appState.sessionManager.switchToGenTab(genTab)
                }
            }
        }
    }

    @ViewBuilder
    private var bookmarksContent: some View {
        let bookmarks = BookmarkManager.shared.bookmarks

        if bookmarks.isEmpty {
            emptyState(message: "No bookmarks", icon: "bookmark")
        } else {
            ForEach(bookmarks.prefix(20)) { bookmark in
                ShelfItemCard(
                    title: bookmark.title,
                    subtitle: URL(string: bookmark.url)?.host ?? bookmark.url,
                    icon: "bookmark.fill",
                    color: .blue
                ) {
                    if let url = URL(string: bookmark.url) {
                        appState.sessionManager.addTab(url: url)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var readingListContent: some View {
        let items = ReadingListManager.shared.items

        if items.isEmpty {
            emptyState(message: "Reading list empty", icon: "eyeglasses")
        } else {
            ForEach(items.prefix(20)) { item in
                ShelfItemCard(
                    title: item.title,
                    subtitle: URL(string: item.url)?.host ?? item.url,
                    icon: "eyeglasses",
                    color: .orange,
                    isUnread: !item.isRead
                ) {
                    if let url = URL(string: item.url) {
                        appState.sessionManager.addTab(url: url)
                        ReadingListManager.shared.markAsRead(id: item.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historyContent: some View {
        let historyItems = HistoryManager.shared.recentHistory(limit: 20)

        if historyItems.isEmpty {
            emptyState(message: "No history", icon: "clock")
        } else {
            ForEach(historyItems, id: \.url) { item in
                ShelfItemCard(
                    title: item.title ?? "Untitled",
                    subtitle: item.url?.host ?? "",
                    icon: "clock.fill",
                    color: .green
                ) {
                    if let url = item.url {
                        appState.sessionManager.addTab(url: url)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(message: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 120, height: 90)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: DynamicShelfView.ShelfCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shelf Item Card

struct ShelfItemCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isUnread: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)

                    Spacer()

                    if isUnread {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(width: 140, height: 90)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(isHovered ? 0.2 : 0.1), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 6 : 3)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Keyboard Shortcut Extension

extension ShortcutManager {
    static let toggleShelfNotification = Notification.Name("CanvasToggleShelf")
}
