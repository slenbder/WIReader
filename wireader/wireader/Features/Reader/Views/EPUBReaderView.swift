import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let chapterURL: URL
    let allowedDir: URL
    var onProgressUpdate: (Double) -> Void = { _ in }
    var onWebViewReady: (WKWebView) -> Void = { _ in }
    var onPageLoaded: () -> Void = {}

    func makeUIView(context: Context) -> WKWebView {
        let userController = WKUserContentController()
        userController.add(WeakScriptHandler(context.coordinator), name: "scrollProgress")

        let config = WKWebViewConfiguration()
        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onPageLoaded = onPageLoaded
        onWebViewReady(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onPageLoaded = onPageLoaded
        guard context.coordinator.lastLoadedURL != chapterURL else { return }
        context.coordinator.lastLoadedURL = chapterURL
        webView.loadFileURL(chapterURL, allowingReadAccessTo: allowedDir)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastLoadedURL: URL?
        var onProgressUpdate: (Double) -> Void = { _ in }
        var onPageLoaded: () -> Void = {}

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let js = """
            window.addEventListener('scroll', function() {
                var pos = window.scrollY;
                var height = document.body.scrollHeight - window.innerHeight;
                var progress = height > 0 ? pos / height : 0;
                window.webkit.messageHandlers.scrollProgress.postMessage(progress);
            }, { passive: true });
            """
            webView.evaluateJavaScript(js)
            onPageLoaded()
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "scrollProgress",
                  let position = message.body as? Double else { return }
            onProgressUpdate(position)
        }
    }

    // MARK: - Weak proxy to avoid retain cycle

    private final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
        weak var target: Coordinator?
        init(_ target: Coordinator) { self.target = target }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            target?.userContentController(userContentController, didReceive: message)
        }
    }
}
