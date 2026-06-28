import SwiftUI
import WebKit
import OSLog

struct EPUBReaderView: UIViewRepresentable {
    let chapterURL: URL
    let allowedDir: URL
    let chapterIndex: Int
    let scrollPosition: Double
    let restoreToken: Int
    let readingMode: ReaderReadingMode
    let theme: ReaderTheme
    var onProgressUpdate: (Double) -> Void = { _ in }
    var onWebViewReady: (WKWebView) -> Void = { _ in }
    var onPageLoaded: () -> Void = {}
    var onTap: () -> Void = {}
    var onSelectionChange: (ReaderTextSelection?) -> Void = { _ in }

    func makeUIView(context: Context) -> WKWebView {
        let userController = WKUserContentController()
        userController.add(WeakScriptHandler(context.coordinator), name: "scrollProgress")
        userController.add(WeakScriptHandler(context.coordinator), name: "readerSelection")

        let config = WKWebViewConfiguration()
        config.userContentController = userController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onPageLoaded = onPageLoaded
        context.coordinator.onTap = onTap
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.chapterIndex = chapterIndex
        context.coordinator.webView = webView
        onWebViewReady(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onPageLoaded = onPageLoaded
        context.coordinator.onTap = onTap
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.chapterIndex = chapterIndex
        context.coordinator.theme = theme
        let tokenChanged = context.coordinator.lastRestoreToken != restoreToken
        if context.coordinator.lastThemeId != theme.id {
            context.coordinator.applyTheme(to: webView)
        }
        guard context.coordinator.lastLoadedURL != chapterURL else {
            if tokenChanged {
                context.coordinator.lastRestoreToken = restoreToken
                context.coordinator.scroll(to: scrollPosition, in: webView)
            }
            return
        }
        context.coordinator.lastLoadedURL = chapterURL
        context.coordinator.chapterIndicesByURL[chapterURL.standardizedFileURL] = chapterIndex
        context.coordinator.lastRestoreToken = restoreToken
        context.coordinator.isFirstRestore = true
        webView.alpha = 0
        webView.loadFileURL(chapterURL, allowingReadAccessTo: allowedDir)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "scrollProgress")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "readerSelection")
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastLoadedURL: URL?
        var chapterIndicesByURL: [URL: Int] = [:]
        var onProgressUpdate: (Double) -> Void = { _ in }
        var onPageLoaded: () -> Void = {}
        var onTap: () -> Void = {}
        var onSelectionChange: (ReaderTextSelection?) -> Void = { _ in }
        var chapterIndex: Int = 0
        var isFirstRestore: Bool = true
        weak var webView: WKWebView?
        var theme: ReaderTheme = .light
        var lastThemeId: String?
        var lastRestoreToken: Int = -1

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // IMPORTANT: EPUB position restore relies on reapply at EVERY didFinish.
            // Testing shows 3 didFinish events per chapter open (sh: 195 → 15313 → 14569).
            // Likely cause: loadFileURL called multiple times when chapterURL changes
            // in rapid succession. Do NOT deduplicate or skip reapply without a
            // compensating mechanism — e.g. waiting for scrollHeight to stabilise —
            // or EPUB restore will regress to pre-Fix-B behaviour (sh=195 drift).
            let loadedURL = webView.url?.standardizedFileURL
            let selectionChapterIndex = loadedURL.flatMap { chapterIndicesByURL[$0] } ?? chapterIndex
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

                if (!window.wireaderTapListenerInstalled) {
                    window.wireaderTapListenerInstalled = true;
                    window.wireaderTapStart = null;
                    window.wireaderLastTapPostedAt = 0;

                    window.wireaderPostTap = function() {
                        var now = Date.now();
                        if (now - window.wireaderLastTapPostedAt < 500) { return; }
                        window.wireaderLastTapPostedAt = now;
                        window.webkit.messageHandlers.scrollProgress.postMessage('tap');
                    };

                    document.addEventListener('touchstart', function(event) {
                        if (event.touches.length !== 1) {
                            window.wireaderTapStart = null;
                            return;
                        }
                        var touch = event.touches[0];
                        window.wireaderTapStart = {
                            x: touch.clientX,
                            y: touch.clientY,
                            t: Date.now()
                        };
                    }, { capture: true, passive: true });

                    document.addEventListener('touchend', function(event) {
                        var start = window.wireaderTapStart;
                        window.wireaderTapStart = null;
                        if (!start || event.changedTouches.length !== 1) { return; }

                        var touch = event.changedTouches[0];
                        var dx = Math.abs(touch.clientX - start.x);
                        var dy = Math.abs(touch.clientY - start.y);
                        var dt = Date.now() - start.t;
                        if (dx <= 10 && dy <= 10 && dt <= 350) {
                            window.wireaderPostTap();
                        }
                    }, { capture: true, passive: true });

                    document.addEventListener('click', function() {
                        window.wireaderPostTap();
                    }, { capture: true, passive: true });
                }

                if (!window.wireaderSelectionListenerInstalled) {
                    window.wireaderSelectionListenerInstalled = true;
                    window.wireaderSelectionTimer = null;

                    window.wireaderPostSelection = function() {
                        var selection = window.getSelection();
                        var selectedText = selection ? selection.toString().trim() : '';
                        if (!selection || selection.rangeCount === 0 || selectedText.length === 0) {
                            window.webkit.messageHandlers.readerSelection.postMessage({
                                selectedText: '',
                                chapterIndex: \(selectionChapterIndex),
                                positionInChapter: 0
                            });
                            return;
                        }

                        var range = selection.getRangeAt(0);
                        var rect = range.getBoundingClientRect();
                        var maxY = Math.max(document.body.scrollHeight - window.innerHeight, 1);
                        var position = Math.min(Math.max((rect.top + window.scrollY) / maxY, 0), 1);
                        window.webkit.messageHandlers.readerSelection.postMessage({
                            selectedText: selectedText,
                            chapterIndex: \(selectionChapterIndex),
                            positionInChapter: position
                        });
                    };

                    window.wireaderScheduleSelectionPost = function() {
                        clearTimeout(window.wireaderSelectionTimer);
                        window.wireaderSelectionTimer = setTimeout(window.wireaderPostSelection, 120);
                    };

                    document.addEventListener('selectionchange', window.wireaderScheduleSelectionPost);
                    document.addEventListener('touchend', function() {
                        setTimeout(window.wireaderPostSelection, 250);
                    }, { capture: true, passive: true });
                }

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

        func scroll(to position: Double, in webView: WKWebView) {
            let clampedPosition = min(max(position, 0.0), 1.0)
            let js = "window.scrollTo(0,(document.body.scrollHeight-window.innerHeight)*\(clampedPosition));"
            webView.evaluateJavaScript(js) { _, error in
                if let error { AppLogger.reader.error("EPUB live scroll JS: \(error.localizedDescription, privacy: .public)") }
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "readerSelection" {
                handleSelectionMessage(message.body)
                return
            }

            guard message.name == "scrollProgress" else { return }
            if let position = message.body as? Double {
                onProgressUpdate(position)
            } else if (message.body as? String) == "tap" {
                onTap()
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

        private func handleSelectionMessage(_ body: Any) {
            guard let payload = body as? [String: Any],
                  let selectedText = payload["selectedText"] as? String,
                  !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let chapterIndex = (payload["chapterIndex"] as? NSNumber)?.intValue,
                  let position = payload["positionInChapter"] as? Double
            else {
                onSelectionChange(nil)
                return
            }

            let selection = ReaderTextSelection(
                selectedText: selectedText,
                chapterIndex: chapterIndex,
                positionInChapter: position
            )
            onSelectionChange(selection.isValid ? selection : nil)
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
