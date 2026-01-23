import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var appState: AppState
    @StateObject private var windowCoordinator = WindowCoordinator()
    @State private var showChat: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            // 1. Navigation Rail (Left sidebar)
            SidebarRail(showChat: $showChat)
                .frame(width: 60)
                .background(CanvasVisualEffect(material: .sidebar, blendingMode: .behindWindow))

            // 2. AI Chat Panel (Left side - Apple design: AI on left, content on right)
            if appState.sessionManager.currentTab != nil && showChat {
                Divider()

                ChatPanelView(onClose: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showChat = false
                    }
                })
                .frame(width: 360)
                .background(Color.canvasBackground)
                .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            // 3. Main Content Area (Takes full remaining width)
            ZStack {
                if let currentTab = appState.sessionManager.currentTab {
                    switch currentTab {
                    case .web:
                        BrowserPanelView()
                    case .gen(let genTab):
                        GenTabView(genTab: genTab)
                    }
                } else {
                    EmptyStateView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.canvasTertiaryBackground)
        }
        .onAppear {
            windowManager.register(windowCoordinator)
        }
        // Handle keyboard shortcut notifications
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.toggleAIPanelNotification)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showChat.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.newTabNotification)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                appState.sessionManager.addTab(url: url)
            } else {
                appState.sessionManager.addTab(url: URL(string: "https://www.google.com")!)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ShortcutManager.closeTabNotification)) { _ in
            if let tabId = appState.sessionManager.currentTabId {
                // Remember URL for reopen functionality
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
        // Fallback Keyboard Shortcuts (Invisible Buttons)
        .background(
            VStack {
                // MARK: - Navigation
                Button("New Tab") {
                    appState.sessionManager.addTab(url: URL(string: "https://google.com")!)
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
                
                Button("Next Tab") {
                    // Implement next tab logic if session manager supports it
                    // appState.sessionManager.selectNextTab()
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])

                Button("Previous Tab") {
                    // Implement prev tab logic
                    // appState.sessionManager.selectPreviousTab()
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                
                Button("Go Back") {
                    NotificationCenter.default.post(name: ShortcutManager.goBackNotification, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)
                
                Button("Go Forward") {
                    NotificationCenter.default.post(name: ShortcutManager.goForwardNotification, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
                
                // MARK: - Page Actions
                Button("Reload") {
                     NotificationCenter.default.post(name: ShortcutManager.reloadNotification, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Button("Reload Ignoring Cache") {
                     NotificationCenter.default.post(
                        name: ShortcutManager.reloadNotification,
                         object: nil,
                        userInfo: ["ignoreCache": true]
                     )
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button("Find in Page") {
                    NotificationCenter.default.post(name: ShortcutManager.findInPageNotification, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Button("Find Next") {
                     NotificationCenter.default.post(
                        name: ShortcutManager.findInPageNotification,
                        object: nil,
                        userInfo: ["action": "next"]
                     )
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Button("Find Previous") {
                     NotificationCenter.default.post(
                        name: ShortcutManager.findInPageNotification,
                        object: nil,
                        userInfo: ["action": "previous"]
                     )
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                
                Button("Print") {
                    NotificationCenter.default.post(name: ShortcutManager.printNotification, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                // MARK: - AI Features
                Button("Toggle AI") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showChat.toggle()
                    }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                
                Button("New GenTab") {
                    NotificationCenter.default.post(name: ShortcutManager.newGenTabNotification, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift]) // Conflict with Find Previous? check priority
                
                 // MARK: - History & Bookmarks
                 Button("History") {
                     NotificationCenter.default.post(name: ShortcutManager.showHistoryNotification, object: nil)
                 }
                 .keyboardShortcut("y", modifiers: .command)
                 
                 Button("Add Bookmark") {
                     NotificationCenter.default.post(name: ShortcutManager.addBookmarkNotification, object: nil)
                 }
                 .keyboardShortcut("d", modifiers: .command)
                 
                 Button("Show Bookmarks") {
                     // NotificationCenter.default.post(name: ShortcutManager.showBookmarksNotification, object: nil)
                 }
                 .keyboardShortcut("b", modifiers: [.command, .shift])
                 
                 Button("Show Downloads") {
                     NotificationCenter.default.post(name: ShortcutManager.showHistoryNotification, object: nil) // Reusing history for now as per menu
                 }
                 .keyboardShortcut("l", modifiers: [.command, .option])
                 
                // MARK: - Developer
                Button("Inspector") {
                    NotificationCenter.default.post(name: ShortcutManager.openInspectorNotification, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                
                Button("View Source") {
                     // NotificationCenter.default.post(name: ShortcutManager.viewSourceNotification, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .option])
                
                Button("JS Console") {
                    // NotificationCenter.default.post(name: ShortcutManager.showJSConsoleNotification, object: nil)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
                
                // MARK: - Zoom
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
                
                // MARK: - Window
                Button("New Window") {
                    NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Close Window") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                
                Button("Minimize") {
                    NSApp.keyWindow?.miniaturize(nil)
                }
                .keyboardShortcut("m", modifiers: .command)
                
                Button("Toggle Fullscreen") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
                
                Button("Settings") {
                     NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                
                // MARK: - Focus
                Button("Focus Address Bar") {
                     NotificationCenter.default.post(name: ShortcutManager.focusAddressBarNotification, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
                
                Button("Focus Search") {
                     // Focus search logic
                }
                .keyboardShortcut("k", modifiers: .command)
            }
            .opacity(0)
            .allowsHitTesting(false)
        )
    }
}
