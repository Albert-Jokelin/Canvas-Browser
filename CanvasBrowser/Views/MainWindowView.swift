import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var appState: AppState
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var showChat: Bool = false
    @State private var showBookmarks: Bool = false
    @State private var showHelp: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab Strip at top
            TabStrip()

            Divider()

            // Main content area - using GeometryReader for stable layout
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // AI Chat Panel (collapsible)
                    if showChat {
                        ChatPanelView(onClose: {
                            showChat = false
                        })
                        .frame(width: 340)
                        .background(Color(NSColor.controlBackgroundColor))

                        Divider()
                    }

                    // Bookmarks/Reading List Sidebar (collapsible)
                    if showBookmarks {
                        BookmarksView(
                            onOpenURL: { url in
                                appState.sessionManager.addTab(url: url)
                                showBookmarks = false
                            },
                            onClose: { showBookmarks = false }
                        )

                        Divider()
                    }

                    // Tab Groups Sidebar (collapsible)
                    if appState.showTabGroupsSidebar {
                        TabGroupsSidebar(
                            groupManager: appState.tabGroupManager,
                            selectedTabId: Binding(
                                get: { appState.sessionManager.currentTabId },
                                set: { appState.sessionManager.currentTabId = $0 }
                            )
                        )
                        .frame(width: 220)
                        .background(Color(NSColor.controlBackgroundColor))

                        Divider()
                    }

                    // Main Content - takes remaining space
                    ZStack(alignment: .top) {
                        if let currentTab = appState.sessionManager.currentTab {
                            switch currentTab {
                            case .web:
                                BrowserPanelView()
                            case .gen(let genTab):
                                GenTabView(
                                    genTab: genTab,
                                    onGenTabUpdate: { updatedGenTab in
                                        appState.sessionManager.updateGenTab(updatedGenTab)
                                    }
                                )
                            }
                        } else {
                            EmptyStateView()
                        }

                        // GenTab Suggestion Banner
                        if appState.aiOrchestrator.showSuggestionBanner,
                           let suggestion = appState.aiOrchestrator.pendingSuggestion {
                            VStack {
                                GenTabSuggestionBanner(
                                    suggestion: suggestion,
                                    onAccept: {
                                        Task {
                                            await appState.aiOrchestrator.acceptSuggestion()
                                        }
                                    },
                                    onDismiss: {
                                        appState.aiOrchestrator.dismissSuggestion()
                                    }
                                )
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.smooth(duration: 0.25), value: showChat)
        .animation(.smooth(duration: 0.25), value: appState.showTabGroupsSidebar)
        .onAppear {
            windowManager.register(windowCoordinator)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                // Toggle Chat
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showChat.toggle()
                    }
                }) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .foregroundColor(showChat ? .accentColor : .secondary)
                }
                .help("Toggle AI Chat (⌘⇧K)")

                // Toggle Tab Groups
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.showTabGroupsSidebar.toggle()
                    }
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(appState.showTabGroupsSidebar ? .accentColor : .secondary)
                }
                .help("Toggle Tab Groups (⌘⌥G)")
            }
        }
        // Keyboard shortcuts
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
        // Bookmarks and Reading List
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showBookmarksNotification)) { _ in
            withAnimation(.smooth(duration: 0.25)) {
                showBookmarks.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showReadingListNotification)) { _ in
            withAnimation(.smooth(duration: 0.25)) {
                showBookmarks = true // Opens bookmarks view which has reading list tab
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.addBookmarkNotification)) { _ in
            // Add current page to bookmarks
            if let tab = appState.sessionManager.currentTab,
               case .web(let webTab) = tab {
                let coordinator = appState.sessionManager.coordinator(for: webTab.id)
                let url = coordinator.currentURL ?? webTab.url
                let title = coordinator.pageTitle.isEmpty ? webTab.title : coordinator.pageTitle
                BookmarkManager.shared.addBookmark(url: url.absoluteString, title: title)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.addToReadingListNotification)) { _ in
            // Add current page to reading list
            if let tab = appState.sessionManager.currentTab,
               case .web(let webTab) = tab {
                let coordinator = appState.sessionManager.coordinator(for: webTab.id)
                let url = coordinator.currentURL ?? webTab.url
                let title = coordinator.pageTitle.isEmpty ? webTab.title : coordinator.pageTitle
                ReadingListManager.shared.addItem(url: url.absoluteString, title: title)
            }
        }
        // Private tab and new tab from URL notifications
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.newPrivateTabNotification)) { _ in
            appState.sessionManager.addPrivateTab()
        }
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
        // Help
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showHelpNotification)) { _ in
            showHelp = true
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.showKeyboardShortcutsNotification)) { _ in
            showHelp = true
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        // Invisible keyboard shortcut buttons
        .background(
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
        )
    }
}
