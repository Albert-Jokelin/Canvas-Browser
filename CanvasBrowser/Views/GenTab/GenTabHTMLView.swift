import SwiftUI
import WebKit

struct GenTabHTMLView: View {
    let html: String
    @State private var contentHeight: CGFloat = 200

    var body: some View {
        GenTabHTMLWebView(html: html, contentHeight: $contentHeight)
            .frame(height: contentHeight)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(12)
    }
}

struct GenTabHTMLWebView: NSViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "gentabHeight")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        webView.setValue(false, forKey: "drawsBackground")

        context.coordinator.lastHTML = html
        webView.loadHTMLString(wrappedHTML(html), baseURL: nil)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            nsView.loadHTMLString(wrappedHTML(html), baseURL: nil)
        }
    }

    private func wrappedHTML(_ rawHTML: String) -> String {
        let csp = """
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:;">
        """

        let resizeScript = """
        <script>
        (function() {
          function postHeight() {
            var height = Math.max(
              document.body.scrollHeight,
              document.documentElement.scrollHeight
            );
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.gentabHeight) {
              window.webkit.messageHandlers.gentabHeight.postMessage(height);
            }
          }
          window.addEventListener('load', postHeight);
          window.addEventListener('resize', postHeight);
          if (window.ResizeObserver) {
            var ro = new ResizeObserver(postHeight);
            ro.observe(document.body);
          } else {
            setInterval(postHeight, 500);
          }
        })();
        </script>
        """

        if rawHTML.lowercased().contains("<head>") {
            return rawHTML.replacingOccurrences(of: "<head>", with: "<head>\(csp)\(resizeScript)")
        }

        return """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8">
            \(csp)
            \(resizeScript)
          </head>
          <body>
            \(rawHTML)
          </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let parent: GenTabHTMLWebView
        var lastHTML: String = ""

        init(_ parent: GenTabHTMLWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "gentabHeight" else { return }
            if let height = message.body as? Double {
                DispatchQueue.main.async {
                    self.parent.contentHeight = max(200, CGFloat(height))
                }
            } else if let height = message.body as? Int {
                DispatchQueue.main.async {
                    self.parent.contentHeight = max(200, CGFloat(height))
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url,
               let scheme = url.scheme?.lowercased() {
                if scheme == "about" || scheme == "data" {
                    decisionHandler(.allow)
                    return
                }
            }
            decisionHandler(.cancel)
        }
    }
}
