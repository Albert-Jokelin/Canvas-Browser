import Foundation
import WebKit

/// Extracts content from web tabs for AI analysis
class ContentExtractor: ObservableObject {
    static let shared = ContentExtractor()

    @Published var extractedContent: [UUID: ExtractedContent] = [:]

    struct ExtractedContent: Codable, Identifiable {
        let id: UUID
        let tabId: UUID
        let url: String
        let title: String
        let domain: String
        let textContent: String
        let metaDescription: String?
        let extractedAt: Date

        init(tabId: UUID, url: String, title: String, domain: String, textContent: String, metaDescription: String?) {
            self.id = UUID()
            self.tabId = tabId
            self.url = url
            self.title = title
            self.domain = domain
            self.textContent = textContent
            self.metaDescription = metaDescription
            self.extractedAt = Date()
        }
    }

    /// JavaScript to extract page content
    private let extractionScript = """
    (function() {
        // Get meta description
        const getMeta = (name) => {
            const el = document.querySelector(`meta[name="${name}"], meta[property="${name}"]`);
            return el ? el.getAttribute('content') : null;
        };

        // Try to find main content area
        const mainContent = document.querySelector('article, [role="main"], main, .content, #content, .post, .article');

        // Get text content, preferring main content if found
        let text = '';
        if (mainContent) {
            text = mainContent.innerText;
        } else {
            // Fallback to body, but try to exclude nav, header, footer, sidebar
            const excludeSelectors = ['nav', 'header', 'footer', 'aside', '.sidebar', '.menu', '.navigation'];
            const body = document.body.cloneNode(true);
            excludeSelectors.forEach(sel => {
                body.querySelectorAll(sel).forEach(el => el.remove());
            });
            text = body.innerText;
        }

        // Truncate to reasonable size
        text = text.substring(0, 5000).trim();

        // Clean up whitespace
        text = text.replace(/\\s+/g, ' ');

        return {
            title: document.title || '',
            url: window.location.href,
            domain: window.location.hostname,
            text: text,
            description: getMeta('description') || getMeta('og:description') || null
        };
    })();
    """

    /// Extract content from a single WebView
    func extractContent(from webView: WKWebView, tabId: UUID) async -> ExtractedContent? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                webView.evaluateJavaScript(self.extractionScript) { [weak self] result, error in
                    guard let self = self else {
                        continuation.resume(returning: nil)
                        return
                    }

                    if let error = error {
                        print("Content extraction error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let data = result as? [String: Any] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let content = ExtractedContent(
                        tabId: tabId,
                        url: data["url"] as? String ?? "",
                        title: data["title"] as? String ?? "Untitled",
                        domain: data["domain"] as? String ?? "",
                        textContent: data["text"] as? String ?? "",
                        metaDescription: data["description"] as? String
                    )

                    // Cache the extracted content
                    DispatchQueue.main.async {
                        self.extractedContent[tabId] = content
                    }

                    print("Extracted content from: \(content.domain) - \(content.title)")
                    continuation.resume(returning: content)
                }
            }
        }
    }

    /// Extract content from all provided web tabs
    func extractAllTabs(webTabs: [(id: UUID, webView: WKWebView)]) async -> [ExtractedContent] {
        var results: [ExtractedContent] = []

        for (tabId, webView) in webTabs {
            if let content = await extractContent(from: webView, tabId: tabId) {
                results.append(content)
            }
        }

        return results
    }

    /// Clear cached content for a specific tab
    func clearContent(for tabId: UUID) {
        extractedContent.removeValue(forKey: tabId)
    }

    /// Clear all cached content
    func clearAllContent() {
        extractedContent.removeAll()
    }

    /// Get cached content if still fresh (within 5 minutes)
    func getCachedContent(for tabId: UUID, maxAge: TimeInterval = 300) -> ExtractedContent? {
        guard let content = extractedContent[tabId] else { return nil }

        let age = Date().timeIntervalSince(content.extractedAt)
        if age < maxAge {
            return content
        }

        return nil
    }
}
