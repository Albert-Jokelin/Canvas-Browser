import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var windowManager: WindowManager
    @EnvironmentObject var appState: AppState
    @StateObject private var windowCoordinator = WindowCoordinator()
    @StateObject private var toastManager = ToastManager.shared
    @State private var showChat: Bool = false
    @State private var showBookmarks: Bool = false
    @State private var showHelp: Bool = false
    @State private var showShelf: Bool = false

    var body: some View {
        mainContent
            .background(Color(NSColor.windowBackgroundColor))
            .toast($toastManager.currentToast)
            .animation(.smooth(duration: 0.25), value: showChat)
            .animation(.smooth(duration: 0.25), value: appState.showTabGroupsSidebar)
            .animation(.smooth(duration: 0.25), value: showShelf)
            .onAppear {
                windowManager.register(windowCoordinator)
            }
            .toolbar { toolbarContent }
            .tabNotifications(showChat: $showChat)
            .bookmarkNotifications(showBookmarks: $showBookmarks, toastManager: toastManager)
            .urlTabNotifications()
            .widgetShelfNotifications(showShelf: $showShelf, toastManager: toastManager)
            .helpNotifications(showHelp: $showHelp)
            .sheet(isPresented: $showHelp) {
                HelpView()
            }
            .background(KeyboardShortcutsBackground(showChat: $showChat, showShelf: $showShelf))
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            TabStrip()
            Divider()
            shelfSection
            contentSection
        }
    }

    @ViewBuilder
    private var shelfSection: some View {
        if showShelf {
            DynamicShelfView()
                .transition(.move(edge: .top).combined(with: .opacity))
            Divider()
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        GeometryReader { _ in
            HStack(spacing: 0) {
                chatPanel
                bookmarksPanel
                tabGroupsPanel
                contentArea
            }
        }
    }

    // MARK: - Panels

    @ViewBuilder
    private var chatPanel: some View {
        if showChat {
            ChatPanelView(onClose: {
                showChat = false
            })
            .frame(width: 340)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
        }
    }

    @ViewBuilder
    private var bookmarksPanel: some View {
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
    }

    @ViewBuilder
    private var tabGroupsPanel: some View {
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
    }

    @ViewBuilder
    private var contentArea: some View {
        ZStack(alignment: .top) {
            tabContent
            suggestionBanner
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var tabContent: some View {
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
    }

    @ViewBuilder
    private var suggestionBanner: some View {
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

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showChat.toggle()
                }
            }) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(showChat ? .accentColor : .secondary)
            }
            .help("Toggle AI Chat (⌘⇧K)")

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.showTabGroupsSidebar.toggle()
                }
            }) {
                Image(systemName: "folder")
                    .foregroundColor(appState.showTabGroupsSidebar ? .accentColor : .secondary)
            }
            .help("Toggle Tab Groups (⌘⌥G)")

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showShelf.toggle()
                }
            }) {
                Image(systemName: "rectangle.split.1x2")
                    .foregroundColor(showShelf ? .accentColor : .secondary)
            }
            .help("Toggle Shelf (⌘⇧S)")
        }
    }
}
