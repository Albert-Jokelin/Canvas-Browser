import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
class VoiceCommandDispatcher {
    weak var appState: AppState?

    func dispatch(_ command: VoiceCommand) {
        switch command {
        // MARK: - Navigation
        case .goBack:
            NotificationCenter.default.post(name: ShortcutManager.goBackNotification, object: nil)
        case .goForward:
            NotificationCenter.default.post(name: ShortcutManager.goForwardNotification, object: nil)
        case .reload:
            NotificationCenter.default.post(name: ShortcutManager.reloadNotification, object: nil)
        case .stopLoading:
            currentCoordinator?.stopLoading()
        case .goHome:
            currentCoordinator?.goHome()

        // MARK: - Tabs
        case .newTab:
            NotificationCenter.default.post(name: ShortcutManager.newTabNotification, object: nil)
        case .closeTab:
            NotificationCenter.default.post(name: ShortcutManager.closeTabNotification, object: nil)
        case .nextTab:
            switchTabByOffset(1)
        case .previousTab:
            switchTabByOffset(-1)
        case .switchToTab(let index):
            switchToTabIndex(index)

        // MARK: - URL / Search
        case .navigateToURL(let urlString):
            if let url = URL(string: urlString) {
                currentCoordinator?.load(url)
            }
        case .search(let query):
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            if let url = URL(string: "https://www.google.com/search?q=\(encoded)") {
                currentCoordinator?.load(url)
            }

        // MARK: - Page
        case .scrollUp:
            currentCoordinator?.getWebView().evaluateJavaScript("window.scrollBy(0, -300)")
        case .scrollDown:
            currentCoordinator?.getWebView().evaluateJavaScript("window.scrollBy(0, 300)")
        case .scrollToTop:
            currentCoordinator?.getWebView().evaluateJavaScript("window.scrollTo(0, 0)")
        case .scrollToBottom:
            currentCoordinator?.getWebView().evaluateJavaScript("window.scrollTo(0, document.body.scrollHeight)")
        case .zoomIn:
            NotificationCenter.default.post(name: ShortcutManager.zoomInNotification, object: nil)
        case .zoomOut:
            NotificationCenter.default.post(name: ShortcutManager.zoomOutNotification, object: nil)
        case .zoomReset:
            NotificationCenter.default.post(name: ShortcutManager.zoomResetNotification, object: nil)
        case .findInPage(let text):
            NotificationCenter.default.post(
                name: ShortcutManager.findInPageNotification,
                object: nil,
                userInfo: ["query": text]
            )

        // MARK: - UI
        case .toggleAIChat:
            NotificationCenter.default.post(name: ShortcutManager.toggleAIPanelNotification, object: nil)
        case .toggleBookmarks:
            NotificationCenter.default.post(name: ShortcutManager.showBookmarksNotification, object: nil)
        case .toggleHistory:
            NotificationCenter.default.post(name: ShortcutManager.showHistoryNotification, object: nil)
        case .toggleFullscreen:
            NSApp.keyWindow?.toggleFullScreen(nil)
        case .openSettings:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        // MARK: - AI
        case .askAI(let query):
            // Open the chat panel first so the listener is active
            NotificationCenter.default.post(name: ShortcutManager.toggleAIPanelNotification, object: nil)
            // Small delay to let the view appear before sending the query
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(
                    name: .voiceAIQuery,
                    object: nil,
                    userInfo: ["query": query]
                )
            }
        case .createGenTab:
            NotificationCenter.default.post(name: ShortcutManager.newGenTabNotification, object: nil)

        // MARK: - Browser
        case .addBookmark:
            NotificationCenter.default.post(name: ShortcutManager.addBookmarkNotification, object: nil)
        case .takeScreenshot:
            takeScreenshot()
        case .printPage:
            NotificationCenter.default.post(name: ShortcutManager.printNotification, object: nil)
        case .toggleReaderMode:
            currentCoordinator?.toggleReaderMode()

        // MARK: - Voice
        case .stopListening:
            // Handled by VoiceControlService directly
            break
        }
    }

    // MARK: - Helpers

    private var currentCoordinator: WebViewCoordinator? {
        guard let appState = appState,
              let currentTab = appState.sessionManager.currentTab,
              case .web(let webTab) = currentTab else {
            return nil
        }
        return appState.sessionManager.coordinatorCache[webTab.id]
    }

    private func switchTabByOffset(_ offset: Int) {
        guard let appState = appState else { return }
        let tabs = appState.sessionManager.activeTabs
        guard !tabs.isEmpty else { return }
        guard let currentId = appState.sessionManager.currentTabId,
              let currentIndex = tabs.firstIndex(where: { $0.id == currentId }) else { return }
        let newIndex = (currentIndex + offset + tabs.count) % tabs.count
        appState.sessionManager.currentTabId = tabs[newIndex].id
    }

    private func switchToTabIndex(_ index: Int) {
        guard let appState = appState else { return }
        let tabs = appState.sessionManager.activeTabs
        let adjustedIndex = index - 1 // User says "tab 1" meaning first tab
        guard adjustedIndex >= 0 && adjustedIndex < tabs.count else { return }
        appState.sessionManager.currentTabId = tabs[adjustedIndex].id
    }

    private func takeScreenshot() {
        guard let window = NSApp.keyWindow else { return }
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.boundsIgnoreFraming]
        ) else { return }
        let image = NSImage(cgImage: cgImage, size: window.frame.size)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Canvas Screenshot.png"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let tiffData = image.tiffRepresentation,
                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: url)
                }
            }
        }
    }
}
