import SwiftUI

// MARK: - Tab Notification Handlers

struct TabNotificationModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @Binding var showChat: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.toggleAIPanelNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChat.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.newTabNotification)) { notification in
                if let url = notification.userInfo?["url"] as? URL {
                    appState.sessionManager.addTab(url: url)
                } else {
                    appState.sessionManager.addTab(url: URL(string: "about:blank")!)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.closeTabNotification)) { _ in
                if let tabId = appState.sessionManager.currentTabId {
                    if let tab = appState.sessionManager.currentTab,
                       case .web(let webTab) = tab {
                        ShortcutManager.shared.rememberClosedTab(url: webTab.url)
                    }
                    appState.sessionManager.closeTab(id: tabId)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.newGenTabNotification)) { _ in
                appState.createGenTabFromSelection()
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.newPrivateTabNotification)) { _ in
                appState.sessionManager.addPrivateTab()
            }
    }
}

// MARK: - Bookmark Notification Handlers

struct BookmarkNotificationModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @Binding var showBookmarks: Bool
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showBookmarksNotification)) { _ in
                withAnimation(.smooth(duration: 0.25)) {
                    showBookmarks.toggle()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showReadingListNotification)) { _ in
                withAnimation(.smooth(duration: 0.25)) {
                    showBookmarks = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.addBookmarkNotification)) { _ in
                if let tab = appState.sessionManager.currentTab,
                   case .web(let webTab) = tab {
                    let coordinator = appState.sessionManager.coordinator(for: webTab.id)
                    let url = coordinator.currentURL ?? webTab.url
                    let title = coordinator.pageTitle.isEmpty ? webTab.title : coordinator.pageTitle
                    BookmarkManager.shared.addBookmark(url: url.absoluteString, title: title)
                    toastManager.showBookmarkAdded()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.addToReadingListNotification)) { _ in
                if let tab = appState.sessionManager.currentTab,
                   case .web(let webTab) = tab {
                    let coordinator = appState.sessionManager.coordinator(for: webTab.id)
                    let url = coordinator.currentURL ?? webTab.url
                    let title = coordinator.pageTitle.isEmpty ? webTab.title : coordinator.pageTitle
                    ReadingListManager.shared.addItem(url: url.absoluteString, title: title)
                    toastManager.showReadingListAdded()
                }
            }
    }
}

// MARK: - URL Tab Notification Handlers

struct URLTabNotificationModifier: ViewModifier {
    @EnvironmentObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .createNewTabWithURL)) { notification in
                if let url = notification.userInfo?["url"] as? URL {
                    appState.sessionManager.addTab(url: url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .createPrivateTabWithURL)) { notification in
                if let url = notification.userInfo?["url"] as? URL {
                    appState.sessionManager.addTab(url: url, isPrivate: true)
                }
            }
    }
}

// MARK: - Widget & Shelf Notification Handlers

struct WidgetShelfNotificationModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @Binding var showShelf: Bool
    @ObservedObject var toastManager: ToastManager

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openGenTabInCanvas)) { notification in
                if let genTab = notification.userInfo?["genTab"] as? GenTab {
                    appState.sessionManager.addGenTab(genTab)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .addToShelf)) { notification in
                if notification.userInfo?["genTab"] is GenTab {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showShelf = true
                    }
                    toastManager.show(ToastData(message: "Added to Shelf", icon: "tray.and.arrow.down", style: .success))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .createFloatingWidget)) { notification in
                if let genTab = notification.userInfo?["genTab"] as? GenTab {
                    FloatingWidgetManager.shared.createWidget(from: genTab)
                }
            }
    }
}

// MARK: - Help Notification Handlers

struct HelpNotificationModifier: ViewModifier {
    @Binding var showHelp: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showHelpNotification)) { _ in
                showHelp = true
            }
            .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showKeyboardShortcutsNotification)) { _ in
                showHelp = true
            }
    }
}

// MARK: - Keyboard Shortcuts Group 1

struct KeyboardShortcutsGroup1: View {
    @EnvironmentObject var appState: AppState
    @Binding var showChat: Bool
    @Binding var showShelf: Bool

    var body: some View {
        Group {
            Button("New Tab") {
                appState.sessionManager.addTab(url: URL(string: "about:blank")!)
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("Close Tab") {
                if let tabId = appState.sessionManager.currentTabId {
                    if let tab = appState.sessionManager.currentTab,
                       case .web(let webTab) = tab {
                        ShortcutManager.shared.rememberClosedTab(url: webTab.url)
                    }
                    appState.sessionManager.closeTab(id: tabId)
                }
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("Reopen Closed Tab") {
                if let url = ShortcutManager.shared.popClosedTab() {
                    appState.sessionManager.addTab(url: url)
                }
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("Toggle AI Chat") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChat.toggle()
                }
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Button("Toggle Tab Groups") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.showTabGroupsSidebar.toggle()
                }
            }
            .keyboardShortcut("g", modifiers: [.command, .option])

            Button("New GenTab") {
                appState.createGenTabFromSelection()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])

            Button("Toggle Shelf") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showShelf.toggle()
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}

// MARK: - Keyboard Shortcuts Group 2

struct KeyboardShortcutsGroup2: View {
    var body: some View {
        Group {
            Button("Go Back") {
                NotificationCenter.default.post(name: ShortcutManager.goBackNotification, object: nil)
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Go Forward") {
                NotificationCenter.default.post(name: ShortcutManager.goForwardNotification, object: nil)
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Reload") {
                NotificationCenter.default.post(name: ShortcutManager.reloadNotification, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Find in Page") {
                NotificationCenter.default.post(name: ShortcutManager.findInPageNotification, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Focus Address Bar") {
                NotificationCenter.default.post(name: ShortcutManager.focusAddressBarNotification, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Minimize") {
                NSApp.keyWindow?.miniaturize(nil)
            }
            .keyboardShortcut("m", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}

// MARK: - Keyboard Shortcuts Group 3

struct KeyboardShortcutsGroup3: View {
    var body: some View {
        Group {
            Button("Close Window") {
                NSApp.keyWindow?.close()
            }
            .keyboardShortcut("w", modifiers: [.command, .shift])

            Button("Toggle Fullscreen") {
                NSApp.keyWindow?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .control])

            Button("Zoom In") {
                NotificationCenter.default.post(name: ShortcutManager.zoomInNotification, object: nil)
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                NotificationCenter.default.post(name: ShortcutManager.zoomOutNotification, object: nil)
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Zoom Reset") {
                NotificationCenter.default.post(name: ShortcutManager.zoomResetNotification, object: nil)
            }
            .keyboardShortcut("0", modifiers: .command)
        }
        .opacity(0)
        .allowsHitTesting(false)
    }
}

// MARK: - Combined Keyboard Shortcuts View

struct KeyboardShortcutsBackground: View {
    @EnvironmentObject var appState: AppState
    @Binding var showChat: Bool
    @Binding var showShelf: Bool

    var body: some View {
        ZStack {
            KeyboardShortcutsGroup1(showChat: $showChat, showShelf: $showShelf)
            KeyboardShortcutsGroup2()
            KeyboardShortcutsGroup3()
        }
    }
}

// MARK: - View Extensions

extension View {
    func tabNotifications(showChat: Binding<Bool>) -> some View {
        modifier(TabNotificationModifier(showChat: showChat))
    }

    func bookmarkNotifications(showBookmarks: Binding<Bool>, toastManager: ToastManager) -> some View {
        modifier(BookmarkNotificationModifier(showBookmarks: showBookmarks, toastManager: toastManager))
    }

    func urlTabNotifications() -> some View {
        modifier(URLTabNotificationModifier())
    }

    func widgetShelfNotifications(showShelf: Binding<Bool>, toastManager: ToastManager) -> some View {
        modifier(WidgetShelfNotificationModifier(showShelf: showShelf, toastManager: toastManager))
    }

    func helpNotifications(showHelp: Binding<Bool>) -> some View {
        modifier(HelpNotificationModifier(showHelp: showHelp))
    }
}
