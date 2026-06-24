import SwiftUI
import WebKit
import OSLog

struct EPUBReaderView: UIViewRepresentable {
    let chapterURL: URL
    let allowedDir: URL
    let theme: ReaderTheme
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
        context.coordinator.webView = webView
        onWebViewReady(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onPageLoaded = onPageLoaded
        context.coordinator.theme = theme
        if context.coordinator.lastThemeId != theme.id {
            context.coordinator.applyTheme(to: webView)
        }
        guard context.coordinator.lastLoadedURL != chapterURL else { return }
        context.coordinator.lastLoadedURL = chapterURL
        context.coordinator.isFirstRestore = true
        webView.alpha = 0
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
        var isFirstRestore: Bool = true
        weak var webView: WKWebView?
        var theme: ReaderTheme = .light
        var lastThemeId: String?

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // IMPORTANT: EPUB position restore relies on reapply at EVERY didFinish.
            // Testing shows 3 didFinish events per chapter open (sh: 195 → 15313 → 14569).
            // Likely cause: loadFileURL called multiple times when chapterURL changes
            // in rapid succession. Do NOT deduplicate or skip reapply without a
            // compensating mechanism — e.g. waiting for scrollHeight to stabilise —
            // or EPUB restore will regress to pre-Fix-B behaviour (sh=195 drift).
            let js = """
            (function() {
                window.wireaderApplyTheme = function(css) {
                    var style = document.getElementById('wireader-theme-style');
                    if (!style) {
                        style = document.createElement('style');
                        style.id = 'wireader-theme-style';
                        document.head.appendChild(style);
                    }
                    style.textContent = css;
                };

                window.addEventListener('scroll', function() {
                    var sh = document.body.scrollHeight, ih = window.innerHeight, sy = window.scrollY;
                    var progress = sh > ih ? sy / (sh - ih) : 0;
                    window.webkit.messageHandlers.scrollProgress.postMessage(progress);
                }, { passive: true });

                // Fix B: if load already fired, reapply immediately; otherwise wait.
                if (document.readyState === 'complete') {
                    window.webkit.messageHandlers.scrollProgress.postMessage('reapply');
                } else {
                    window.addEventListener('load', function() {
                        window.webkit.messageHandlers.scrollProgress.postMessage('reapply');
                    }, { once: true });
                }
            })();
            """
            webView.evaluateJavaScript(js) { _, error in
                if let error { AppLogger.reader.error("didFinish JS: \(error.localizedDescription, privacy: .public)") }
            }
            applyTheme(to: webView)
            onPageLoaded()
        }

        func applyTheme(to webView: WKWebView) {
            let css = theme.cssOverride
            guard let cssData = try? JSONEncoder().encode(css),
                  let cssLiteral = String(data: cssData, encoding: .utf8)
            else {
                AppLogger.reader.error("EPUB theme CSS encoding failed")
                return
            }

            let js = """
            (function() {
                var css = \(cssLiteral);
                if (window.wireaderApplyTheme) {
                    window.wireaderApplyTheme(css);
                    return;
                }
                var style = document.getElementById('wireader-theme-style');
                if (!style) {
                    style = document.createElement('style');
                    style.id = 'wireader-theme-style';
                    document.head.appendChild(style);
                }
                style.textContent = css;
            })();
            """
            webView.evaluateJavaScript(js) { [themeId = theme.id, weak self] _, error in
                if let error {
                    AppLogger.reader.error("EPUB theme JS: \(error.localizedDescription, privacy: .public)")
                } else {
                    self?.lastThemeId = themeId
                }
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "scrollProgress" else { return }
            if let position = message.body as? Double {
                onProgressUpdate(position)
            } else if (message.body as? String) == "reapply" {
                onPageLoaded()
                if isFirstRestore {
                    isFirstRestore = false
                    DispatchQueue.main.async { [weak webView] in
                        UIView.animate(withDuration: 0.15) { webView?.alpha = 1 }
                    }
                }
            }
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
