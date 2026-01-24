import SwiftUI
import AppKit
import Combine

// MARK: - Shortcut Definitions

enum CanvasShortcut: String, CaseIterable {
    // Navigation
    case newTab
    case closeTab
    case reopenClosedTab
    case nextTab
    case previousTab
    case goBack
    case goForward

    // Page Actions
    case reload
    case reloadIgnoringCache
    case stopLoading
    case findInPage
    case findNext
    case findPrevious
    case print

    // AI Features
    case toggleAIPanel
    case newGenTab
    case detachGenTab
    case focusAIInput

    // History & Bookmarks
    case showHistory
    case addBookmark
    case showBookmarks
    case showDownloads

    // Developer
    case openInspector
    case viewSource
    case showJavaScriptConsole

    // Zoom
    case zoomIn
    case zoomOut
    case zoomReset

    // Window
    case newWindow
    case closeWindow
    case minimizeWindow
    case toggleFullscreen
    case showSettings

    // Focus
    case focusAddressBar
    case focusSearchField

    var key: KeyEquivalent {
        switch self {
        // Navigation
        case .newTab: return "t"
        case .closeTab: return "w"
        case .reopenClosedTab: return "t"
        case .nextTab: return "]"
        case .previousTab: return "["
        case .goBack: return "["
        case .goForward: return "]"

        // Page Actions
        case .reload: return "r"
        case .reloadIgnoringCache: return "r"
        case .stopLoading: return "."
        case .findInPage: return "f"
        case .findNext: return "g"
        case .findPrevious: return "g"
        case .print: return "p"

        // AI Features
        case .toggleAIPanel: return "k"
        case .newGenTab: return "g"
        case .detachGenTab: return "d"
        case .focusAIInput: return "j"

        // History & Bookmarks
        case .showHistory: return "y"
        case .addBookmark: return "d"
        case .showBookmarks: return "b"
        case .showDownloads: return "l"

        // Developer
        case .openInspector: return "i"
        case .viewSource: return "u"
        case .showJavaScriptConsole: return "c"

        // Zoom
        case .zoomIn: return "+"
        case .zoomOut: return "-"
        case .zoomReset: return "0"

        // Window
        case .newWindow: return "n"
        case .closeWindow: return "w"
        case .minimizeWindow: return "m"
        case .toggleFullscreen: return "f"
        case .showSettings: return ","

        // Focus
        case .focusAddressBar: return "l"
        case .focusSearchField: return "k"
        }
    }

    var modifiers: EventModifiers {
        switch self {
        // Navigation with Shift
        case .reopenClosedTab: return [.command, .shift]
        case .nextTab, .previousTab: return [.command, .shift]
        case .goBack, .goForward: return .command

        // Page Actions
        case .reload: return .command
        case .reloadIgnoringCache: return [.command, .shift]
        case .stopLoading: return .command
        case .findInPage: return .command
        case .findNext: return .command
        case .findPrevious: return [.command, .shift]
        case .print: return .command

        // AI Features (Cmd+Shift)
        case .toggleAIPanel: return [.command, .shift]
        case .newGenTab: return [.command, .shift]
        case .detachGenTab: return [.command, .shift]
        case .focusAIInput: return [.command, .shift]

        // History & Bookmarks
        case .showHistory: return .command
        case .addBookmark: return .command
        case .showBookmarks: return [.command, .shift]
        case .showDownloads: return [.command, .option]

        // Developer (Cmd+Opt)
        case .openInspector: return [.command, .option]
        case .viewSource: return [.command, .option]
        case .showJavaScriptConsole: return [.command, .option]

        // Zoom
        case .zoomIn: return .command
        case .zoomOut: return .command
        case .zoomReset: return .command

        // Window
        case .newWindow: return .command
        case .closeWindow: return [.command, .shift]
        case .minimizeWindow: return .command
        case .toggleFullscreen: return [.command, .control]
        case .showSettings: return .command

        // Focus
        case .focusAddressBar: return .command
        case .focusSearchField: return .command

        default: return .command
        }
    }

    var displayName: String {
        switch self {
        case .newTab: return "New Tab"
        case .closeTab: return "Close Tab"
        case .reopenClosedTab: return "Reopen Closed Tab"
        case .nextTab: return "Show Next Tab"
        case .previousTab: return "Show Previous Tab"
        case .goBack: return "Go Back"
        case .goForward: return "Go Forward"
        case .reload: return "Reload Page"
        case .reloadIgnoringCache: return "Reload Ignoring Cache"
        case .stopLoading: return "Stop Loading"
        case .findInPage: return "Find in Page"
        case .findNext: return "Find Next"
        case .findPrevious: return "Find Previous"
        case .print: return "Print..."
        case .toggleAIPanel: return "Toggle AI Panel"
        case .newGenTab: return "New GenTab"
        case .detachGenTab: return "Detach GenTab"
        case .focusAIInput: return "Focus AI Input"
        case .showHistory: return "Show History"
        case .addBookmark: return "Add Bookmark"
        case .showBookmarks: return "Show Bookmarks"
        case .showDownloads: return "Show Downloads"
        case .openInspector: return "Open Web Inspector"
        case .viewSource: return "View Page Source"
        case .showJavaScriptConsole: return "Show JavaScript Console"
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .zoomReset: return "Actual Size"
        case .newWindow: return "New Window"
        case .closeWindow: return "Close Window"
        case .minimizeWindow: return "Minimize"
        case .toggleFullscreen: return "Toggle Full Screen"
        case .showSettings: return "Settings..."
        case .focusAddressBar: return "Focus Address Bar"
        case .focusSearchField: return "Focus Search Field"
        }
    }

    var shortcutDisplay: String {
        var result = ""
        if modifiers.contains(.control) { result += "^" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }

        let keyString: String
        switch key {
        case "+": keyString = "+"
        case "-": keyString = "-"
        case "[": keyString = "["
        case "]": keyString = "]"
        case ",": keyString = ","
        case ".": keyString = "."
        default: keyString = String(key.character).uppercased()
        }

        return result + keyString
    }
}

// MARK: - Shortcut Manager

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    @Published var isAIPanelVisible = true
    @Published var isFindBarVisible = false
    @Published var currentZoom: Double = 1.0

    private var closedTabs: [(URL, Date)] = []
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    // Notification names for shortcut actions
    static let toggleAIPanelNotification = Notification.Name("CanvasToggleAIPanel")
    static let newTabNotification = Notification.Name("CanvasNewTab")
    static let closeTabNotification = Notification.Name("CanvasCloseTab")
    static let reloadNotification = Notification.Name("CanvasReload")
    static let findInPageNotification = Notification.Name("CanvasFindInPage")
    static let zoomInNotification = Notification.Name("CanvasZoomIn")
    static let zoomOutNotification = Notification.Name("CanvasZoomOut")
    static let zoomResetNotification = Notification.Name("CanvasZoomReset")
    static let goBackNotification = Notification.Name("CanvasGoBack")
    static let goForwardNotification = Notification.Name("CanvasGoForward")
    static let showHistoryNotification = Notification.Name("CanvasShowHistory")
    static let addBookmarkNotification = Notification.Name("CanvasAddBookmark")
    static let openInspectorNotification = Notification.Name("CanvasOpenInspector")
    static let focusAddressBarNotification = Notification.Name("CanvasFocusAddressBar")
    static let newGenTabNotification = Notification.Name("CanvasNewGenTab")
    static let printNotification = Notification.Name("CanvasPrint")

    // New notifications for bookmarks, reading list, and help
    static let addToReadingListNotification = Notification.Name("CanvasAddToReadingList")
    static let showBookmarksNotification = Notification.Name("CanvasShowBookmarks")
    static let showReadingListNotification = Notification.Name("CanvasShowReadingList")
    static let newPrivateTabNotification = Notification.Name("CanvasNewPrivateTab")
    static let showHelpNotification = Notification.Name("CanvasShowHelp")
    static let showKeyboardShortcutsNotification = Notification.Name("CanvasShowKeyboardShortcuts")
    static let viewSourceNotification = Notification.Name("CanvasViewSource")

    private init() {
        setupGlobalShortcuts()
    }

    private func setupGlobalShortcuts() {
        // Global event monitor for shortcuts that need to work everywhere
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil // Consume the event
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }

        let hasShift = event.modifierFlags.contains(.shift)
        let hasOption = event.modifierFlags.contains(.option)
        let hasControl = event.modifierFlags.contains(.control)

        guard let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }

        // Handle Cmd+Shift+K for AI toggle
        if chars == "k" && hasShift && !hasOption && !hasControl {
            toggleAIPanel()
            return true
        }

        // Handle Cmd+Shift+G for new GenTab
        if chars == "g" && hasShift && !hasOption && !hasControl {
            NotificationCenter.default.post(name: ShortcutManager.newGenTabNotification, object: nil)
            return true
        }

        return false
    }

    func toggleAIPanel() {
        isAIPanelVisible.toggle()
        NotificationCenter.default.post(name: ShortcutManager.toggleAIPanelNotification, object: nil)
    }

    func rememberClosedTab(url: URL) {
        closedTabs.append((url, Date()))
        // Keep only last 50 closed tabs
        if closedTabs.count > 50 {
            closedTabs.removeFirst()
        }
    }

    func popClosedTab() -> URL? {
        return closedTabs.popLast()?.0
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - SwiftUI Commands

struct CanvasCommands: Commands {
    @ObservedObject var shortcutManager = ShortcutManager.shared

    var body: some Commands {
        // Replace standard File menu items
        CommandGroup(replacing: .newItem) {
            Button(CanvasShortcut.newTab.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.newTabNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.newTab.key, modifiers: CanvasShortcut.newTab.modifiers)

            Button(CanvasShortcut.newWindow.displayName) {
                NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
            }
            .keyboardShortcut(CanvasShortcut.newWindow.key, modifiers: CanvasShortcut.newWindow.modifiers)

            Divider()

            Button(CanvasShortcut.closeTab.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.closeTabNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.closeTab.key, modifiers: CanvasShortcut.closeTab.modifiers)

            Button(CanvasShortcut.reopenClosedTab.displayName) {
                if let url = shortcutManager.popClosedTab() {
                    NotificationCenter.default.post(
                        name: ShortcutManager.newTabNotification,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
            }
            .keyboardShortcut(CanvasShortcut.reopenClosedTab.key, modifiers: CanvasShortcut.reopenClosedTab.modifiers)
        }

        // Edit menu additions
        CommandGroup(after: .pasteboard) {
            Divider()

            Button(CanvasShortcut.findInPage.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.findInPageNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.findInPage.key, modifiers: CanvasShortcut.findInPage.modifiers)

            Button(CanvasShortcut.findNext.displayName) {
                NotificationCenter.default.post(
                    name: ShortcutManager.findInPageNotification,
                    object: nil,
                    userInfo: ["action": "next"]
                )
            }
            .keyboardShortcut(CanvasShortcut.findNext.key, modifiers: CanvasShortcut.findNext.modifiers)

            Button(CanvasShortcut.findPrevious.displayName) {
                NotificationCenter.default.post(
                    name: ShortcutManager.findInPageNotification,
                    object: nil,
                    userInfo: ["action": "previous"]
                )
            }
            .keyboardShortcut(CanvasShortcut.findPrevious.key, modifiers: CanvasShortcut.findPrevious.modifiers)
        }

        // View menu
        CommandGroup(replacing: .toolbar) {
            Button(CanvasShortcut.toggleAIPanel.displayName) {
                shortcutManager.toggleAIPanel()
            }
            .keyboardShortcut(CanvasShortcut.toggleAIPanel.key, modifiers: CanvasShortcut.toggleAIPanel.modifiers)

            Divider()

            Button(CanvasShortcut.reload.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.reloadNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.reload.key, modifiers: CanvasShortcut.reload.modifiers)

            Button(CanvasShortcut.reloadIgnoringCache.displayName) {
                NotificationCenter.default.post(
                    name: ShortcutManager.reloadNotification,
                    object: nil,
                    userInfo: ["ignoreCache": true]
                )
            }
            .keyboardShortcut(CanvasShortcut.reloadIgnoringCache.key, modifiers: CanvasShortcut.reloadIgnoringCache.modifiers)

            Divider()

            Button(CanvasShortcut.zoomIn.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.zoomInNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.zoomIn.key, modifiers: CanvasShortcut.zoomIn.modifiers)

            Button(CanvasShortcut.zoomOut.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.zoomOutNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.zoomOut.key, modifiers: CanvasShortcut.zoomOut.modifiers)

            Button(CanvasShortcut.zoomReset.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.zoomResetNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.zoomReset.key, modifiers: CanvasShortcut.zoomReset.modifiers)

            Divider()

            Button(CanvasShortcut.toggleFullscreen.displayName) {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut(CanvasShortcut.toggleFullscreen.key, modifiers: CanvasShortcut.toggleFullscreen.modifiers)
        }

        // History menu
        CommandMenu("History") {
            Button(CanvasShortcut.goBack.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.goBackNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.goBack.key, modifiers: CanvasShortcut.goBack.modifiers)

            Button(CanvasShortcut.goForward.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.goForwardNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.goForward.key, modifiers: CanvasShortcut.goForward.modifiers)

            Divider()

            Button(CanvasShortcut.showHistory.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.showHistoryNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.showHistory.key, modifiers: CanvasShortcut.showHistory.modifiers)
        }

        // Bookmarks menu
        CommandMenu("Bookmarks") {
            Button(CanvasShortcut.addBookmark.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.addBookmarkNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.addBookmark.key, modifiers: CanvasShortcut.addBookmark.modifiers)

            Button("Add to Reading List") {
                NotificationCenter.default.post(name: ShortcutManager.addToReadingListNotification, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button(CanvasShortcut.showBookmarks.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.showBookmarksNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.showBookmarks.key, modifiers: CanvasShortcut.showBookmarks.modifiers)

            Button("Show Reading List") {
                NotificationCenter.default.post(name: ShortcutManager.showReadingListNotification, object: nil)
            }

            Divider()

            Button(CanvasShortcut.showDownloads.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.showHistoryNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.showDownloads.key, modifiers: CanvasShortcut.showDownloads.modifiers)
        }

        // AI menu
        CommandMenu("AI") {
            Button(CanvasShortcut.toggleAIPanel.displayName) {
                shortcutManager.toggleAIPanel()
            }
            .keyboardShortcut(CanvasShortcut.toggleAIPanel.key, modifiers: CanvasShortcut.toggleAIPanel.modifiers)

            Divider()

            Button(CanvasShortcut.newGenTab.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.newGenTabNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.newGenTab.key, modifiers: CanvasShortcut.newGenTab.modifiers)

            Button(CanvasShortcut.detachGenTab.displayName) {
                // Detach current GenTab to new window
            }
            .keyboardShortcut(CanvasShortcut.detachGenTab.key, modifiers: CanvasShortcut.detachGenTab.modifiers)

            Divider()

            Button(CanvasShortcut.focusAIInput.displayName) {
                // Focus AI input field
            }
            .keyboardShortcut(CanvasShortcut.focusAIInput.key, modifiers: CanvasShortcut.focusAIInput.modifiers)
        }

        // Developer menu
        CommandMenu("Develop") {
            Button(CanvasShortcut.openInspector.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.openInspectorNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.openInspector.key, modifiers: CanvasShortcut.openInspector.modifiers)

            Button(CanvasShortcut.viewSource.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.viewSourceNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.viewSource.key, modifiers: CanvasShortcut.viewSource.modifiers)

            Button(CanvasShortcut.showJavaScriptConsole.displayName) {
                NotificationCenter.default.post(name: ShortcutManager.openInspectorNotification, object: nil)
            }
            .keyboardShortcut(CanvasShortcut.showJavaScriptConsole.key, modifiers: CanvasShortcut.showJavaScriptConsole.modifiers)

            Divider()

            Button("New Private Tab") {
                NotificationCenter.default.post(name: ShortcutManager.newPrivateTabNotification, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        // Help menu
        CommandMenu("Help") {
            Button("Canvas Browser Help") {
                NotificationCenter.default.post(name: ShortcutManager.showHelpNotification, object: nil)
            }
            .keyboardShortcut("?", modifiers: .command)

            Button("Keyboard Shortcuts") {
                NotificationCenter.default.post(name: ShortcutManager.showKeyboardShortcutsNotification, object: nil)
            }

            Divider()

            Button("Report an Issue...") {
                if let url = URL(string: "https://github.com/anthropics/claude-code/issues") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("About Canvas Browser") {
                NSApp.orderFrontStandardAboutPanel(nil)
            }
        }
    }
}

// MARK: - View Extension for Shortcut Handling

extension View {
    func handleShortcuts(
        onToggleAI: @escaping () -> Void = {},
        onNewTab: @escaping () -> Void = {},
        onCloseTab: @escaping () -> Void = {},
        onReload: @escaping () -> Void = {},
        onGoBack: @escaping () -> Void = {},
        onGoForward: @escaping () -> Void = {}
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.toggleAIPanelNotification)) { _ in
                onToggleAI()
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.newTabNotification)) { _ in
                onNewTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.closeTabNotification)) { _ in
                onCloseTab()
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.reloadNotification)) { _ in
                onReload()
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.goBackNotification)) { _ in
                onGoBack()
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.goForwardNotification)) { _ in
                onGoForward()
            }
    }
}

// MARK: - Shortcut Hint View

struct ShortcutHintView: View {
    let shortcut: CanvasShortcut

    var body: some View {
        HStack(spacing: 4) {
            Text(shortcut.displayName)
                .foregroundColor(.secondary)
            Text(shortcut.shortcutDisplay)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                )
        }
    }
}

// MARK: - Keyboard Shortcuts Reference View

struct KeyboardShortcutsReferenceView: View {
    let categories: [(String, [CanvasShortcut])] = [
        ("Navigation", [.newTab, .closeTab, .reopenClosedTab, .nextTab, .previousTab, .goBack, .goForward]),
        ("Page", [.reload, .reloadIgnoringCache, .stopLoading, .findInPage, .print]),
        ("AI Features", [.toggleAIPanel, .newGenTab, .detachGenTab, .focusAIInput]),
        ("History & Bookmarks", [.showHistory, .addBookmark, .showBookmarks, .showDownloads]),
        ("Developer", [.openInspector, .viewSource, .showJavaScriptConsole]),
        ("Zoom", [.zoomIn, .zoomOut, .zoomReset]),
        ("Window", [.newWindow, .closeWindow, .minimizeWindow, .toggleFullscreen, .showSettings])
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(categories, id: \.0) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category.0)
                            .font(.headline)
                            .foregroundColor(.primary)

                        ForEach(category.1, id: \.rawValue) { shortcut in
                            HStack {
                                Text(shortcut.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(shortcut.shortcutDisplay)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                }
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}
