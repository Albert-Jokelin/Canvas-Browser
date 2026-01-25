import WidgetKit
import SwiftUI

// MARK: - Bookmarks Widget

struct BookmarksWidget: Widget {
    let kind: String = "BookmarksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BookmarksProvider()) { entry in
            BookmarksWidgetView(entry: entry)
        }
        .configurationDisplayName("Bookmarks")
        .description("Quick access to your favorite bookmarks.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct BookmarksProvider: TimelineProvider {
    func placeholder(in context: Context) -> BookmarksEntry {
        BookmarksEntry(date: Date(), bookmarks: BookmarkEntry.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BookmarksEntry) -> Void) {
        let entry = BookmarksEntry(date: Date(), bookmarks: WidgetDataProvider.getBookmarks())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BookmarksEntry>) -> Void) {
        let entry = BookmarksEntry(date: Date(), bookmarks: WidgetDataProvider.getBookmarks())
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BookmarksEntry: TimelineEntry {
    let date: Date
    let bookmarks: [BookmarkEntry]
}

// MARK: - Widget View

struct BookmarksWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: BookmarksEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Bookmarks")
                    .font(.caption.bold())
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.bookmarks.prefix(3)) { bookmark in
                    Link(destination: URL(string: bookmark.url)!) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(bookmark.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.blue)
                Text("Bookmarks")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(entry.bookmarks.prefix(6)) { bookmark in
                    Link(destination: URL(string: bookmark.url)!) {
                        HStack(spacing: 8) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)

                            Text(bookmark.title)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    BookmarksWidget()
} timeline: {
    BookmarksEntry(date: Date(), bookmarks: BookmarkEntry.placeholder)
}
