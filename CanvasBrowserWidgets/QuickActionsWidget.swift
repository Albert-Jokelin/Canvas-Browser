import WidgetKit
import SwiftUI

// MARK: - Quick Actions Widget

struct QuickActionsWidget: Widget {
    let kind: String = "QuickActionsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickActionsProvider()) { entry in
            QuickActionsWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Actions")
        .description("Quick shortcuts to Canvas Browser features.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Timeline Provider

struct QuickActionsProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickActionsEntry {
        QuickActionsEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickActionsEntry) -> Void) {
        completion(QuickActionsEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickActionsEntry>) -> Void) {
        let entry = QuickActionsEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickActionsEntry: TimelineEntry {
    let date: Date
}

// MARK: - Quick Action Model

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let url: String
}

// MARK: - Widget View

struct QuickActionsWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickActionsEntry

    private let actions: [QuickAction] = [
        QuickAction(title: "New Tab", icon: "plus.square", color: .blue, url: "canvas://new-tab"),
        QuickAction(title: "New GenTab", icon: "sparkles", color: .purple, url: "canvas://new-gentab"),
        QuickAction(title: "AI Chat", icon: "bubble.left.and.bubble.right", color: .green, url: "canvas://ai-chat"),
        QuickAction(title: "Bookmarks", icon: "bookmark.fill", color: .orange, url: "canvas://bookmarks"),
        QuickAction(title: "History", icon: "clock.fill", color: .gray, url: "canvas://history"),
        QuickAction(title: "Private Tab", icon: "eye.slash.fill", color: .indigo, url: "canvas://private-tab")
    ]

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
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.purple)
                Text("Canvas")
                    .font(.caption.bold())
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(actions.prefix(4)) { action in
                    Link(destination: URL(string: action.url)!) {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.title3)
                                .foregroundColor(action.color)
                            Text(action.title)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(action.color.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }

    private var mediumView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.purple)
                Text("Canvas Quick Actions")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(actions) { action in
                    Link(destination: URL(string: action.url)!) {
                        VStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.title2)
                                .foregroundColor(action.color)
                            Text(action.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(action.color.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    QuickActionsWidget()
} timeline: {
    QuickActionsEntry(date: Date())
}
