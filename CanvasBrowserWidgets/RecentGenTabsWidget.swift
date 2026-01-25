import WidgetKit
import SwiftUI

// MARK: - Recent GenTabs Widget

struct RecentGenTabsWidget: Widget {
    let kind: String = "RecentGenTabsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GenTabsProvider()) { entry in
            RecentGenTabsWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent GenTabs")
        .description("Quick access to your recent AI-generated tabs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Provider

struct GenTabsProvider: TimelineProvider {
    func placeholder(in context: Context) -> GenTabsEntry {
        GenTabsEntry(date: Date(), genTabs: GenTabEntry.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (GenTabsEntry) -> Void) {
        let entry = GenTabsEntry(date: Date(), genTabs: WidgetDataProvider.getRecentGenTabs())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GenTabsEntry>) -> Void) {
        let entry = GenTabsEntry(date: Date(), genTabs: WidgetDataProvider.getRecentGenTabs())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct GenTabsEntry: TimelineEntry {
    let date: Date
    let genTabs: [GenTabEntry]
}

// MARK: - Widget View

struct RecentGenTabsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: GenTabsEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge:
            largeView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.purple)
                Text("GenTabs")
                    .font(.caption.bold())
            }

            if let first = entry.genTabs.first {
                Link(destination: URL(string: "canvas://gentab/\(first.id)")!) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: first.icon)
                                .font(.title2)
                                .foregroundColor(.purple)
                            Spacer()
                        }
                        Text(first.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(first.preview)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
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
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Recent GenTabs")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                ForEach(entry.genTabs.prefix(3)) { genTab in
                    Link(destination: URL(string: "canvas://gentab/\(genTab.id)")!) {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: genTab.icon)
                                .font(.title2)
                                .foregroundColor(.purple)
                                .frame(height: 30)
                            Text(genTab.title)
                                .font(.caption.bold())
                                .lineLimit(2)
                            Text(genTab.preview)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Recent GenTabs")
                    .font(.headline)
                Spacer()
                Link(destination: URL(string: "canvas://new-gentab")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }

            ForEach(entry.genTabs.prefix(5)) { genTab in
                Link(destination: URL(string: "canvas://gentab/\(genTab.id)")!) {
                    HStack(spacing: 12) {
                        Image(systemName: genTab.icon)
                            .font(.title2)
                            .foregroundColor(.purple)
                            .frame(width: 40, height: 40)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(genTab.title)
                                .font(.subheadline.bold())
                                .lineLimit(1)
                            Text(genTab.preview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(genTab.date, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    RecentGenTabsWidget()
} timeline: {
    GenTabsEntry(date: Date(), genTabs: GenTabEntry.placeholder)
}
