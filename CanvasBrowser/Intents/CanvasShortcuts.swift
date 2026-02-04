import AppIntents

/// Provides pre-configured shortcuts for the Shortcuts app
struct CanvasShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Search shortcut
        AppShortcut(
            intent: SearchIntent(),
            phrases: [
                "Search \(.applicationName) for \(\.$query)",
                "Search in \(.applicationName) for \(\.$query)",
                "Look up \(\.$query) in \(.applicationName)",
                "Find \(\.$query) with \(.applicationName)"
            ],
            shortTitle: "Search Canvas",
            systemImageName: "magnifyingglass"
        )

        // Open URL shortcut
        AppShortcut(
            intent: OpenURLIntent(),
            phrases: [
                "Open \(\.$url) in \(.applicationName)",
                "Go to \(\.$url) with \(.applicationName)",
                "Browse \(\.$url) in \(.applicationName)"
            ],
            shortTitle: "Open URL",
            systemImageName: "link"
        )

        // Create GenTab shortcut
        AppShortcut(
            intent: CreateGenTabIntent(),
            phrases: [
                "Create a GenTab about \(\.$topic) in \(.applicationName)",
                "Make a \(\.$genTabType) about \(\.$topic) with \(.applicationName)",
                "Generate a tab for \(\.$topic) in \(.applicationName)"
            ],
            shortTitle: "Create GenTab",
            systemImageName: "sparkles.rectangle.stack"
        )

        // Ask AI shortcut
        AppShortcut(
            intent: AskAIIntent(),
            phrases: [
                "Ask \(.applicationName) \(\.$question)",
                "Ask \(.applicationName) AI \(\.$question)",
                "Hey \(.applicationName), \(\.$question)"
            ],
            shortTitle: "Ask AI",
            systemImageName: "brain"
        )

        // Open bookmark shortcut
        AppShortcut(
            intent: OpenBookmarkIntent(),
            phrases: [
                "Open my \(\.$bookmark) bookmark in \(.applicationName)",
                "Open \(\.$bookmark) bookmark",
                "Go to \(\.$bookmark) in \(.applicationName)"
            ],
            shortTitle: "Open Bookmark",
            systemImageName: "bookmark.fill"
        )

        // Add to reading list shortcut
        AppShortcut(
            intent: AddToReadingListIntent(),
            phrases: [
                "Save this for later in \(.applicationName)",
                "Add to reading list in \(.applicationName)",
                "Read this later with \(.applicationName)"
            ],
            shortTitle: "Save for Later",
            systemImageName: "book"
        )

        // Summarize page shortcut
        AppShortcut(
            intent: SummarizePageIntent(),
            phrases: [
                "Summarize this page with \(.applicationName)",
                "Give me a summary in \(.applicationName)",
                "What's this page about in \(.applicationName)"
            ],
            shortTitle: "Summarize Page",
            systemImageName: "doc.text"
        )

        // New tab shortcut
        AppShortcut(
            intent: NewTabIntent(),
            phrases: [
                "New tab in \(.applicationName)",
                "Open new tab in \(.applicationName)"
            ],
            shortTitle: "New Tab",
            systemImageName: "plus.square"
        )

        // Toggle AI panel shortcut
        AppShortcut(
            intent: ToggleAIPanelIntent(),
            phrases: [
                "Show AI in \(.applicationName)",
                "Hide AI in \(.applicationName)",
                "Toggle AI panel in \(.applicationName)"
            ],
            shortTitle: "Toggle AI",
            systemImageName: "sidebar.right"
        )
    }
}
