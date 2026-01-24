import WebKit
import SwiftUI
import Combine

class WebViewCoordinator: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var estimatedProgress: Double = 0
    @Published var pageTitle: String = ""
    @Published var pageURL: URL?
    @Published var favicon: NSImage?

    // Safari features
    @Published var findInPageQuery: String = ""
    @Published var findInPageResults: Int = 0
    @Published var readerModeAvailable = false
    @Published var readerModeActive = false
    @Published var securityLevel: SecurityLevel = .unknown

    // Zoom
    @Published var zoomLevel: Double = 1.0

    enum SecurityLevel {
        case secure, insecure, unknown

        var icon: String {
            switch self {
            case .secure: return "lock.fill"
            case .insecure: return "exclamationmark.triangle.fill"
            case .unknown: return "globe"
            }
        }

        var color: Color {
            switch self {
            case .secure: return .canvasGreen
            case .insecure: return .canvasOrange
            case .unknown: return .canvasSecondaryLabel
            }
        }
    }

    // MARK: - Private Properties

    private var webView: WKWebView!
    private var observations: [NSKeyValueObservation] = []
    private var originalURL: URL?

    /// Whether this coordinator is in private browsing mode
    @Published var isPrivateBrowsing: Bool = false

    // MARK: - Initialization

    override init() {
        super.init()
        setupWebView(isPrivate: false)
        setupObservers()
    }

    /// Initialize with private browsing mode
    convenience init(isPrivate: Bool) {
        self.init()
        if isPrivate {
            self.isPrivateBrowsing = true
            setupWebView(isPrivate: true)
            setupObservers()
        }
    }

    private func setupWebView(isPrivate: Bool = false) {
        let config = WKWebViewConfiguration()

        // Enable all Safari features
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        config.defaultWebpagePreferences = preferences

        // Custom user agent
        config.applicationNameForUserAgent = "CanvasBrowser/1.0 Safari/605.1.15"

        // Web preferences
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        // Private browsing: use non-persistent data store
        if isPrivate {
            config.websiteDataStore = .nonPersistent()
        }

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Custom appearance
        webView.setValue(false, forKey: "drawsBackground")
    }

    private func setupObservers() {
        // Navigation state
        observations.append(
            webView.observe(\.canGoBack, options: [.new, .initial]) { [weak self] _, change in
                DispatchQueue.main.async {
                    self?.canGoBack = change.newValue ?? false
                }
            }
        )

        observations.append(
            webView.observe(\.canGoForward, options: [.new, .initial]) { [weak self] _, change in
                DispatchQueue.main.async {
                    self?.canGoForward = change.newValue ?? false
                }
            }
        )

        observations.append(
            webView.observe(\.isLoading, options: [.new, .initial]) { [weak self] _, change in
                DispatchQueue.main.async {
                    self?.isLoading = change.newValue ?? false
                }
            }
        )

        observations.append(
            webView.observe(\.estimatedProgress, options: [.new, .initial]) { [weak self] _, change in
                DispatchQueue.main.async {
                    self?.estimatedProgress = change.newValue ?? 0
                }
            }
        )

        observations.append(
            webView.observe(\.title, options: [.new, .initial]) { [weak self] _, change in
                DispatchQueue.main.async {
                    self?.pageTitle = (change.newValue as? String) ?? ""
                }
            }
        )

        observations.append(
            webView.observe(\.url, options: [.new, .initial]) { [weak self] _, change in
                DispatchQueue.main.async {
                    self?.pageURL = change.newValue ?? nil
                    self?.updateSecurityLevel()
                }
            }
        )
    }

    // MARK: - Public API

    func getWebView() -> WKWebView {
        return webView
    }

    func createWebView(for tab: BrowsingSession.WebTab) -> WKWebView {
        load(tab.url)
        return webView
    }

    func setActive(_ webView: WKWebView) {
        // Keep reference to the active webview for multi-tab scenarios
        // In single-tab mode, this is already our webView
    }

    func load(_ url: URL) {
        originalURL = url
        webView.load(URLRequest(url: url))
    }

    func loadHTMLString(_ html: String, baseURL: URL? = nil) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func reloadFromOrigin() {
        webView.reloadFromOrigin()
    }

    func reloadIgnoringCache() {
        webView.reloadFromOrigin()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    var currentURL: URL? {
        return pageURL
    }

    func goHome() {
        load(URL(string: "about:blank")!)
    }

    // MARK: - Find in Page

    func findInPage(_ query: String) {
        findInPageQuery = query

        if query.isEmpty {
            clearFindInPage()
            return
        }

        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.wraps = true

        webView.find(query, configuration: config) { [weak self] result in
            DispatchQueue.main.async {
                self?.findInPageResults = result.matchFound ? 1 : 0
            }
        }
    }

    func findNext() {
        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.wraps = true
        config.backwards = false

        webView.find(findInPageQuery, configuration: config) { _ in }
    }

    func findPrevious() {
        let config = WKFindConfiguration()
        config.caseSensitive = false
        config.wraps = true
        config.backwards = true

        webView.find(findInPageQuery, configuration: config) { _ in }
    }

    func clearFindInPage() {
        findInPageQuery = ""
        findInPageResults = 0

        // Clear highlights
        webView.evaluateJavaScript("window.getSelection().removeAllRanges()") { _, _ in }
    }

    // MARK: - Reader Mode

    func toggleReaderMode() {
        if readerModeActive {
            exitReaderMode()
        } else {
            enterReaderMode()
        }
    }

    private func checkReaderMode() {
        let script = """
        (function() {
            const article = document.querySelector('article') ||
                           document.querySelector('[role="main"]') ||
                           document.querySelector('main');
            const text = document.body.innerText;
            return text.length > 1000 && article !== null;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, _ in
            DispatchQueue.main.async {
                self?.readerModeAvailable = (result as? Bool) ?? false
            }
        }
    }

    private func enterReaderMode() {
        let readerScript = """
        (function() {
            const article = document.querySelector('article') ||
                           document.querySelector('[role="main"]') ||
                           document.querySelector('main') ||
                           document.body;

            const images = article.querySelectorAll('img');
            let mainImage = null;
            for (let img of images) {
                if (img.width > 200 && img.height > 150) {
                    mainImage = img.src;
                    break;
                }
            }

            return {
                title: document.title,
                content: article.innerHTML,
                textContent: article.textContent,
                mainImage: mainImage,
                url: window.location.href
            };
        })();
        """

        webView.evaluateJavaScript(readerScript) { [weak self] result, error in
            if let articleData = result as? [String: Any] {
                self?.displayReaderMode(articleData)
            }
        }
    }

    private func displayReaderMode(_ articleData: [String: Any]) {
        let title = articleData["title"] as? String ?? "Article"
        let content = articleData["content"] as? String ?? ""
        let url = articleData["url"] as? String ?? ""

        let readerHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>\(title)</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
                    font-size: 19px;
                    line-height: 1.7;
                    max-width: 680px;
                    margin: 60px auto;
                    padding: 0 24px;
                    color: #1d1d1f;
                    background: #f5f5f7;
                    -webkit-font-smoothing: antialiased;
                }
                @media (prefers-color-scheme: dark) {
                    body {
                        background: #1c1c1e;
                        color: #f5f5f7;
                    }
                    a { color: #0a84ff; }
                }
                h1 {
                    font-size: 34px;
                    font-weight: 700;
                    line-height: 1.2;
                    margin-bottom: 16px;
                }
                .source {
                    font-size: 14px;
                    color: #86868b;
                    margin-bottom: 32px;
                }
                p { margin: 24px 0; }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 12px;
                    margin: 24px 0;
                }
                a { color: #0066cc; text-decoration: none; }
                a:hover { text-decoration: underline; }
                blockquote {
                    border-left: 4px solid #0066cc;
                    padding-left: 20px;
                    margin: 24px 0;
                    font-style: italic;
                    color: #6e6e73;
                }
                code {
                    font-family: "SF Mono", monospace;
                    font-size: 16px;
                    background: rgba(0,0,0,0.05);
                    padding: 2px 6px;
                    border-radius: 4px;
                }
                @media (prefers-color-scheme: dark) {
                    code { background: rgba(255,255,255,0.1); }
                    blockquote { color: #a1a1a6; }
                }
            </style>
        </head>
        <body>
            <h1>\(title)</h1>
            <div class="source">\(url)</div>
            \(content)
        </body>
        </html>
        """

        webView.loadHTMLString(readerHTML, baseURL: URL(string: url))
        readerModeActive = true
    }

    private func exitReaderMode() {
        if let url = originalURL {
            load(url)
        } else {
            webView.goBack()
        }
        readerModeActive = false
    }

    // MARK: - Zoom

    func zoomIn() {
        zoomLevel = min(zoomLevel + 0.1, 3.0)
        applyZoom()
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel - 0.1, 0.5)
        applyZoom()
    }

    func resetZoom() {
        zoomLevel = 1.0
        applyZoom()
    }

    private func applyZoom() {
        webView.pageZoom = zoomLevel
    }

    // MARK: - Screenshot

    func takeSnapshot(completion: @escaping (NSImage?) -> Void) {
        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, error in
            completion(image)
        }
    }

    func takeScreenshot() {
        takeSnapshot { [weak self] image in
            guard let image = image else { return }

            // Save to desktop
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let filename = "Canvas Screenshot \(timestamp).png"
            let fileURL = desktopURL.appendingPathComponent(filename)

            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                do {
                    try pngData.write(to: fileURL)

                    // Show notification
                    let notification = NSUserNotification()
                    notification.title = "Screenshot Saved"
                    notification.informativeText = "Saved to Desktop"
                    NSUserNotificationCenter.default.deliver(notification)
                } catch {
                    print("Failed to save screenshot: \(error)")
                }
            }
        }
    }

    // MARK: - Print

    func printPage() {
        let printInfo = NSPrintInfo.shared
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 36
        printInfo.rightMargin = 36

        let printOperation = webView.printOperation(with: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true

        if let window = NSApp.keyWindow {
            printOperation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        }
    }

    // MARK: - Developer Tools

    func openWebInspector() {
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Open Web Inspector via responder chain
        let selector = NSSelectorFromString("_showInspector")
        if webView.responds(to: selector) {
            webView.perform(selector)
        }
    }

    func viewPageSource() {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, _ in
            if let html = result as? String {
                self?.showSourceWindow(html: html)
            }
        }
    }

    private func showSourceWindow(html: String) {
        let sourceWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        sourceWindow.title = "Page Source - \(pageTitle)"
        sourceWindow.center()

        let scrollView = NSScrollView(frame: sourceWindow.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.string = html

        scrollView.documentView = textView
        sourceWindow.contentView = scrollView
        sourceWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - Favicon

    private func extractFavicon() {
        let faviconScript = """
        (function() {
            const links = document.querySelectorAll('link[rel*="icon"]');
            for (let link of links) {
                if (link.href) return link.href;
            }
            // Fallback to /favicon.ico
            return new URL('/favicon.ico', window.location.origin).href;
        })();
        """

        webView.evaluateJavaScript(faviconScript) { [weak self] result, _ in
            if let faviconURL = result as? String, let url = URL(string: faviconURL) {
                self?.downloadFavicon(url)
            }
        }
    }

    private func downloadFavicon(_ url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                return
            }

            DispatchQueue.main.async {
                self?.favicon = image
            }
        }.resume()
    }

    // MARK: - Security

    private func updateSecurityLevel() {
        guard let url = pageURL else {
            securityLevel = .unknown
            return
        }

        if url.scheme == "https" {
            securityLevel = .secure
        } else if url.scheme == "http" {
            securityLevel = .insecure
        } else {
            securityLevel = .unknown
        }
    }

    // MARK: - Cleanup

    deinit {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
    }
}

// MARK: - WKNavigationDelegate

extension WebViewCoordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Save to history
        if let url = webView.url, url.scheme != "about" {
            HistoryManager.shared.addVisit(url: url.absoluteString, title: webView.title ?? "")
        }

        // Check for reader mode
        checkReaderMode()

        // Extract favicon
        extractFavicon()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Handle common errors
        let nsError = error as NSError
        if nsError.code == NSURLErrorCancelled { return }

        print("Provisional navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Handle special URL schemes
        switch url.scheme {
        case "tel", "mailto", "facetime", "sms":
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        case "itms-apps", "itms-appss":
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        default:
            break
        }

        // Handle target="_blank" links
        if navigationAction.targetFrame == nil {
            // Open in new tab
            NotificationCenter.default.post(
                name: .createNewTabWithURL,
                object: nil,
                userInfo: ["url": url]
            )
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        // Check for downloads
        if let response = navigationResponse.response as? HTTPURLResponse,
           let contentDisposition = response.allHeaderFields["Content-Disposition"] as? String,
           contentDisposition.contains("attachment") {
            // Trigger download
            if let url = response.url {
                NotificationCenter.default.post(
                    name: .startDownload,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension WebViewCoordinator: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        // Handle popup windows - open in new tab
        if let url = navigationAction.request.url {
            NotificationCenter.default.post(
                name: .createNewTabWithURL,
                object: nil,
                userInfo: ["url": url]
            )
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {

        let alert = NSAlert()
        alert.messageText = pageTitle
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {

        let alert = NSAlert()
        alert.messageText = pageTitle
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {

        let alert = NSAlert()
        alert.messageText = pageTitle
        alert.informativeText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            completionHandler(textField.stringValue)
        } else {
            completionHandler(nil)
        }
    }
}

// MARK: - Context Menu Actions

extension WebViewCoordinator {
    func openInNewTab(_ url: URL) {
        NotificationCenter.default.post(
            name: .createNewTabWithURL,
            object: nil,
            userInfo: ["url": url]
        )
    }

    func openInPrivateTab(_ url: URL) {
        NotificationCenter.default.post(
            name: .createPrivateTabWithURL,
            object: nil,
            userInfo: ["url": url]
        )
    }

    func copyLinkToClipboard(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    func addCurrentToReadingList(_ url: URL) {
        let title = pageTitle.isEmpty ? url.host ?? "Untitled" : pageTitle
        ReadingListManager.shared.addItem(url: url.absoluteString, title: title)
    }

    func addCurrentToBookmarks(_ url: URL) {
        let title = pageTitle.isEmpty ? url.host ?? "Untitled" : pageTitle
        BookmarkManager.shared.addBookmark(url: url.absoluteString, title: title)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let createNewTabWithURL = Notification.Name("createNewTabWithURL")
    static let createPrivateTabWithURL = Notification.Name("createPrivateTabWithURL")
    static let startDownload = Notification.Name("startDownload")
}
