import SwiftUI

struct HistoryView: View {
    let onOpenURL: (URL) -> Void
    let onClose: () -> Void

    @StateObject private var historyManager = HistoryManager.shared
    @State private var historyItems: [HistoryItem] = []
    @State private var searchText = ""

    private var filteredItems: [HistoryItem] {
        if searchText.isEmpty {
            return historyItems
        }
        return historyItems.filter { item in
            let title = item.title?.lowercased() ?? ""
            let url = item.url?.absoluteString.lowercased() ?? ""
            let query = searchText.lowercased()
            return title.contains(query) || url.contains(query)
        }
    }

    /// Group history items by date
    private var groupedItems: [(String, [HistoryItem])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [HistoryItem]] = [:]

        for item in filteredItems {
            let key: String
            if calendar.isDateInToday(item.visitDate) {
                key = "Today"
            } else if calendar.isDateInYesterday(item.visitDate) {
                key = "Yesterday"
            } else if let daysAgo = calendar.dateComponents([.day], from: item.visitDate, to: now).day, daysAgo < 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE" // Day name
                key = formatter.string(from: item.visitDate)
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                key = formatter.string(from: item.visitDate)
            }

            groups[key, default: []].append(item)
        }

        // Sort groups by most recent first
        let sortOrder = ["Today", "Yesterday"]
        return groups.sorted { a, b in
            let aIndex = sortOrder.firstIndex(of: a.key) ?? Int.max
            let bIndex = sortOrder.firstIndex(of: b.key) ?? Int.max
            if aIndex != bIndex {
                return aIndex < bIndex
            }
            // For dates not in sortOrder, compare the actual dates
            let aDate = a.value.first?.visitDate ?? Date.distantPast
            let bDate = b.value.first?.visitDate ?? Date.distantPast
            return aDate > bDate
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("History")
                    .font(.headline)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            // History List
            if historyItems.isEmpty {
                emptyState
            } else if filteredItems.isEmpty {
                noResultsState
            } else {
                historyList
            }
        }
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadHistory()
        }
    }

    // MARK: - Views

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No History")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Pages you visit will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No Results")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("No history matches '\(searchText)'")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedItems, id: \.0) { group in
                    Section {
                        ForEach(group.1) { item in
                            HistoryRow(item: item) {
                                if let url = item.url {
                                    onOpenURL(url)
                                }
                            }
                        }
                    } header: {
                        Text(group.0)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadHistory() {
        historyItems = historyManager.getRecentHistory(limit: 500)
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let item: HistoryItem
    let onTap: () -> Void

    @State private var isHovered = false

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: item.visitDate)
    }

    private var domain: String {
        item.url?.host ?? ""
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Time
                Text(timeString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)

                // Favicon placeholder
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)

                // Title and URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title ?? "Untitled")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
