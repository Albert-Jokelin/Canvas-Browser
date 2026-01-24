import SwiftUI

/// Sidebar view for managing bookmarks and reading list
struct BookmarksView: View {
    @StateObject private var bookmarkManager = BookmarkManager.shared
    @StateObject private var readingListManager = ReadingListManager.shared
    @State private var selectedTab: BookmarksTab = .bookmarks
    @State private var searchText = ""
    @State private var editingBookmark: Bookmark?
    @State private var showingNewFolder = false
    @State private var newFolderName = ""

    var onOpenURL: (URL) -> Void
    var onClose: () -> Void

    enum BookmarksTab: String, CaseIterable {
        case bookmarks = "Bookmarks"
        case readingList = "Reading List"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Library")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(BookmarksTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // Content
            switch selectedTab {
            case .bookmarks:
                BookmarksListView(
                    bookmarkManager: bookmarkManager,
                    searchText: searchText,
                    onOpenURL: onOpenURL,
                    onEdit: { editingBookmark = $0 },
                    showingNewFolder: $showingNewFolder
                )
            case .readingList:
                ReadingListView(
                    readingListManager: readingListManager,
                    searchText: searchText,
                    onOpenURL: onOpenURL
                )
            }
        }
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(item: $editingBookmark) { bookmark in
            BookmarkEditSheet(bookmark: bookmark, bookmarkManager: bookmarkManager)
        }
        .sheet(isPresented: $showingNewFolder) {
            NewFolderSheet(
                folderName: $newFolderName,
                onCreate: {
                    bookmarkManager.createFolder(name: newFolderName)
                    newFolderName = ""
                    showingNewFolder = false
                },
                onCancel: {
                    newFolderName = ""
                    showingNewFolder = false
                }
            )
        }
    }
}

// MARK: - Bookmarks List

struct BookmarksListView: View {
    @ObservedObject var bookmarkManager: BookmarkManager
    let searchText: String
    let onOpenURL: (URL) -> Void
    let onEdit: (Bookmark) -> Void
    @Binding var showingNewFolder: Bool

    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return bookmarkManager.bookmarks
        }
        return bookmarkManager.bookmarks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button(action: { showingNewFolder = true }) {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if filteredBookmarks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Bookmarks")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Press ⌘D to bookmark the current page")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredBookmarks) { bookmark in
                        BookmarkRow(bookmark: bookmark)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let url = URL(string: bookmark.url) {
                                    onOpenURL(url)
                                }
                            }
                            .contextMenu {
                                Button("Open") {
                                    if let url = URL(string: bookmark.url) {
                                        onOpenURL(url)
                                    }
                                }
                                Button("Open in New Tab") {
                                    if let url = URL(string: bookmark.url) {
                                        NotificationCenter.default.post(
                                            name: .createNewTabWithURL,
                                            object: nil,
                                            userInfo: ["url": url]
                                        )
                                    }
                                }
                                Divider()
                                Button("Edit") {
                                    onEdit(bookmark)
                                }
                                Button("Delete", role: .destructive) {
                                    bookmarkManager.removeBookmark(id: bookmark.id)
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text(bookmark.url)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reading List View

struct ReadingListView: View {
    @ObservedObject var readingListManager: ReadingListManager
    let searchText: String
    let onOpenURL: (URL) -> Void

    var filteredItems: [ReadingListItem] {
        let items = readingListManager.items
        if searchText.isEmpty {
            return items
        }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.url.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        if filteredItems.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No Reading List Items")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Press ⌘⇧D to add pages to read later")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // Unread section
                if !readingListManager.unreadItems.isEmpty {
                    Section("Unread") {
                        ForEach(filteredItems.filter { !$0.isRead }) { item in
                            ReadingListRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: item.url) {
                                        onOpenURL(url)
                                        readingListManager.markAsRead(id: item.id)
                                    }
                                }
                                .contextMenu {
                                    Button("Mark as Read") {
                                        readingListManager.markAsRead(id: item.id)
                                    }
                                    Button("Delete", role: .destructive) {
                                        readingListManager.removeItem(id: item.id)
                                    }
                                }
                        }
                    }
                }

                // Read section
                if !readingListManager.readItems.isEmpty {
                    Section("Read") {
                        ForEach(filteredItems.filter { $0.isRead }) { item in
                            ReadingListRow(item: item)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let url = URL(string: item.url) {
                                        onOpenURL(url)
                                    }
                                }
                                .contextMenu {
                                    Button("Mark as Unread") {
                                        readingListManager.markAsUnread(id: item.id)
                                    }
                                    Button("Delete", role: .destructive) {
                                        readingListManager.removeItem(id: item.id)
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct ReadingListRow: View {
    let item: ReadingListItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isRead ? "checkmark.circle.fill" : "circle")
                .foregroundColor(item.isRead ? .green : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(item.isRead ? .secondary : .primary)
                if let excerpt = item.excerpt {
                    Text(excerpt)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Sheet

struct BookmarkEditSheet: View {
    let bookmark: Bookmark
    @ObservedObject var bookmarkManager: BookmarkManager
    @Environment(\.dismiss) var dismiss
    @State private var title: String
    @State private var url: String

    init(bookmark: Bookmark, bookmarkManager: BookmarkManager) {
        self.bookmark = bookmark
        self.bookmarkManager = bookmarkManager
        _title = State(initialValue: bookmark.title)
        _url = State(initialValue: bookmark.url)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Bookmark")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("URL", text: $url)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    var updated = bookmark
                    updated.title = title
                    updated.url = url
                    bookmarkManager.updateBookmark(updated)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || url.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct NewFolderSheet: View {
    @Binding var folderName: String
    let onCreate: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("New Folder")
                .font(.headline)

            TextField("Folder Name", text: $folderName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create", action: onCreate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(folderName.isEmpty)
            }
        }
        .padding()
        .frame(width: 250)
    }
}
