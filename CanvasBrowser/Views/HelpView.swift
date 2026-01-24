import SwiftUI

/// Help and keyboard shortcuts reference view
struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: HelpTab = .shortcuts

    enum HelpTab: String, CaseIterable {
        case shortcuts = "Shortcuts"
        case features = "Features"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Canvas Browser Help")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(HelpTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()
                .padding(.top)

            // Content
            ScrollView {
                switch selectedTab {
                case .shortcuts:
                    KeyboardShortcutsSection()
                case .features:
                    FeaturesSection()
                case .about:
                    AboutSection()
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Keyboard Shortcuts Section

struct KeyboardShortcutsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ShortcutGroup(title: "Tabs", shortcuts: [
                ("New Tab", "⌘T"),
                ("Close Tab", "⌘W"),
                ("Reopen Closed Tab", "⌘⇧T"),
                ("New Private Tab", "⌘⇧P"),
                ("Next Tab", "⌃⇥"),
                ("Previous Tab", "⌃⇧⇥")
            ])

            ShortcutGroup(title: "Navigation", shortcuts: [
                ("Go Back", "⌘["),
                ("Go Forward", "⌘]"),
                ("Reload", "⌘R"),
                ("Reload (Ignore Cache)", "⌘⇧R"),
                ("Stop Loading", "⎋"),
                ("Focus Address Bar", "⌘L")
            ])

            ShortcutGroup(title: "View", shortcuts: [
                ("Zoom In", "⌘+"),
                ("Zoom Out", "⌘-"),
                ("Reset Zoom", "⌘0"),
                ("Toggle Fullscreen", "⌃⌘F"),
                ("Find in Page", "⌘F")
            ])

            ShortcutGroup(title: "AI & GenTabs", shortcuts: [
                ("Toggle AI Chat", "⌘⇧K"),
                ("Create GenTab", "⌘⇧G"),
                ("Toggle Tab Groups", "⌘⌥G")
            ])

            ShortcutGroup(title: "Bookmarks", shortcuts: [
                ("Add Bookmark", "⌘D"),
                ("Add to Reading List", "⌘⇧D"),
                ("Show Bookmarks", "⌘⇧B")
            ])

            ShortcutGroup(title: "Developer", shortcuts: [
                ("Web Inspector", "⌘⌥I"),
                ("View Source", "⌘⌥U")
            ])
        }
        .padding()
    }
}

struct ShortcutGroup: View {
    let title: String
    let shortcuts: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                ForEach(shortcuts, id: \.0) { name, key in
                    HStack {
                        Text(name)
                            .font(.system(size: 13))
                        Spacer()
                        Text(key)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
}

// MARK: - Features Section

struct FeaturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            FeatureItem(
                icon: "sparkles",
                title: "AI-Powered GenTabs",
                description: "Create interactive summaries from your open tabs. AI analyzes your browsing context and generates dynamic mini-apps with tables, cards, maps, and more."
            )

            FeatureItem(
                icon: "bubble.left.and.bubble.right",
                title: "Integrated AI Chat",
                description: "Chat with AI about your current page or ask general questions. Press ⌘⇧K to toggle the chat panel."
            )

            FeatureItem(
                icon: "folder",
                title: "Tab Groups",
                description: "Organize your tabs into groups. Save research sessions, projects, or topics for later. Press ⌘⌥G to toggle the sidebar."
            )

            FeatureItem(
                icon: "eyeglasses",
                title: "Reading List",
                description: "Save articles to read later. Press ⌘⇧D to add the current page to your reading list."
            )

            FeatureItem(
                icon: "hand.raised",
                title: "Private Browsing",
                description: "Browse without saving history, cookies, or cache. Press ⌘⇧P to open a new private tab."
            )

            FeatureItem(
                icon: "lock.fill",
                title: "Security Indicator",
                description: "Click the lock icon in the address bar to view site security details including HTTPS status and domain information."
            )
        }
        .padding()
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - About Section

struct AboutSection: View {
    var body: some View {
        VStack(spacing: 24) {
            // Logo
            Image(systemName: "safari")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 8) {
                Text("Canvas Browser")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version 1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("An AI-powered browser for macOS that combines modern web browsing with intelligent features like GenTabs, integrated AI chat, and smart tab organization.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 60)

            VStack(spacing: 8) {
                Text("Built with SwiftUI")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("Powered by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Gemini AI")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }

            Spacer()
        }
        .padding(.top, 40)
    }
}

// MARK: - Preview

#if DEBUG
struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
    }
}
#endif
