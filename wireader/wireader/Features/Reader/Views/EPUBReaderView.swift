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
    var onPageSettled: (Double) -> Void = { _ in }
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
        context.coordinator.onPageSettled = onPageSettled
        context.coordinator.onTap = onTap
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.chapterIndex = chapterIndex
        context.coordinator.readingMode = readingMode
        context.coordinator.webView = webView
        context.coordinator.configureScrolling(for: readingMode, in: webView)
        onWebViewReady(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onPageLoaded = onPageLoaded
        context.coordinator.onPageSettled = onPageSettled
        context.coordinator.onTap = onTap
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.chapterIndex = chapterIndex
        context.coordinator.theme = theme
        context.coordinator.readingMode = readingMode
        let tokenChanged = context.coordinator.lastRestoreToken != restoreToken
        let modeChanged = context.coordinator.lastReadingMode != readingMode
        if context.coordinator.lastThemeId != theme.id {
            context.coordinator.applyTheme(to: webView)
        }
        guard context.coordinator.lastLoadedURL != chapterURL else {
            if modeChanged {
                context.coordinator.lastReadingMode = readingMode
                context.coordinator.lastRestoreToken = restoreToken
                context.coordinator.configureScrolling(for: readingMode, in: webView)
                context.coordinator.applyReadingMode(readingMode, to: webView) {
                    context.coordinator.restore(to: scrollPosition, in: webView)
                }
            }
            if tokenChanged && !modeChanged {
                context.coordinator.lastRestoreToken = restoreToken
                context.coordinator.restore(to: scrollPosition, in: webView)
            }
            return
        }
        context.coordinator.lastLoadedURL = chapterURL
        context.coordinator.chapterIndicesByURL[chapterURL.standardizedFileURL] = chapterIndex
        context.coordinator.lastRestoreToken = restoreToken
        context.coordinator.lastReadingMode = readingMode
        context.coordinator.isFirstRestore = true
        context.coordinator.configureScrolling(for: readingMode, in: webView)
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
        var onPageSettled: (Double) -> Void = { _ in }
        var onTap: () -> Void = {}
        var onSelectionChange: (ReaderTextSelection?) -> Void = { _ in }
        var chapterIndex: Int = 0
        var isFirstRestore: Bool = true
        weak var webView: WKWebView?
        var theme: ReaderTheme = .light
        var lastThemeId: String?
        var lastRestoreToken: Int = -1
        var readingMode: ReaderReadingMode = .scroll
        var lastReadingMode: ReaderReadingMode?

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

                window.wireaderSetReadingMode = function(mode) {
                    window.wireaderReadingMode = mode;
                    var style = document.getElementById('wireader-layout-style');

                    if (mode === 'scroll') {
                        if (style) { style.remove(); }
                        window.scrollTo(0, window.scrollY);
                        return;
                    }

                    if (!style) {
                        style = document.createElement('style');
                        style.id = 'wireader-layout-style';
                        document.head.appendChild(style);
                    }
                    style.textContent = `
                        html {
                            width: 100% !important;
                            height: 100% !important;
                            overflow-x: scroll !important;
                            overflow-y: hidden !important;
                        }
                        body {
                            box-sizing: border-box !important;
                            width: auto !important;
                            height: 100vh !important;
                            max-height: 100vh !important;
                            margin: 0 !important;
                            padding: 0 !important;
                            -webkit-column-width: 100vw !important;
                            -webkit-column-gap: 0 !important;
                            column-width: 100vw !important;
                            column-gap: 0 !important;
                            column-fill: auto !important;
                            overflow: visible !important;
                        }
                        img, svg, video {
                            max-width: 100% !important;
                            max-height: 100vh !important;
                        }
                    `;
                    window.scrollTo(window.scrollX, 0);
                };

                window.wireaderClampPosition = function(position) {
                    return Math.min(Math.max(Number(position) || 0, 0), 1);
                };

                window.wireaderPagingMetrics = function() {
                    var pageWidth = Math.max(window.innerWidth, document.documentElement.clientWidth, 1);
                    var bodyWidth = document.body ? document.body.scrollWidth : 0;
                    var scrollWidth = Math.max(document.documentElement.scrollWidth, bodyWidth, pageWidth);
                    var pageCount = Math.max(Math.ceil((scrollWidth - 0.5) / pageWidth), 1);
                    return {
                        pageWidth: pageWidth,
                        pageCount: pageCount,
                        maxPageIndex: Math.max(pageCount - 1, 0),
                        maxX: Math.max(scrollWidth - pageWidth, 0)
                    };
                };

                window.wireaderCurrentPosition = function() {
                    if (window.wireaderReadingMode === 'paging') {
                        var metrics = window.wireaderPagingMetrics();
                        if (metrics.maxPageIndex === 0) { return 0; }
                        var pageIndex = Math.round(window.scrollX / metrics.pageWidth);
                        pageIndex = Math.min(Math.max(pageIndex, 0), metrics.maxPageIndex);
                        return pageIndex / metrics.maxPageIndex;
                    }

                    var bodyHeight = document.body ? document.body.scrollHeight : 0;
                    var scrollHeight = Math.max(document.documentElement.scrollHeight, bodyHeight);
                    var maxY = Math.max(scrollHeight - window.innerHeight, 0);
                    return maxY > 0 ? window.wireaderClampPosition(window.scrollY / maxY) : 0;
                };

                window.wireaderRestorePosition = function(position) {
                    var clampedPosition = window.wireaderClampPosition(position);
                    if (window.wireaderReadingMode === 'paging') {
                        var metrics = window.wireaderPagingMetrics();
                        var targetPage = Math.round(clampedPosition * metrics.maxPageIndex);
                        var targetX = Math.min(targetPage * metrics.pageWidth, metrics.maxX);
                        window.scrollTo(targetX, 0);
                        return;
                    }

                    var bodyHeight = document.body ? document.body.scrollHeight : 0;
                    var scrollHeight = Math.max(document.documentElement.scrollHeight, bodyHeight);
                    var maxY = Math.max(scrollHeight - window.innerHeight, 0);
                    window.scrollTo(0, maxY * clampedPosition);
                };

                if (!window.wireaderScrollListenerInstalled) {
                    window.wireaderScrollListenerInstalled = true;
                    window.wireaderPageSettleTimer = null;
                    window.wireaderUserGestureActive = false;
                    window.wireaderDidScrollSinceTouch = false;
                    window.wireaderTouchIsDown = false;
                    window.wireaderSchedulePageSettle = function() {
                        clearTimeout(window.wireaderPageSettleTimer);
                        window.wireaderPageSettleTimer = setTimeout(function() {
                            if (window.wireaderTouchIsDown) { return; }
                            var userInitiated = window.wireaderDidScrollSinceTouch === true;
                            window.webkit.messageHandlers.scrollProgress.postMessage({
                                type: 'pageSettled',
                                position: window.wireaderCurrentPosition(),
                                userInitiated: userInitiated
                            });
                            window.wireaderUserGestureActive = false;
                            window.wireaderDidScrollSinceTouch = false;
                        }, 140);
                    };
                    window.addEventListener('scroll', function() {
                        var progress = window.wireaderCurrentPosition();
                        window.webkit.messageHandlers.scrollProgress.postMessage(progress);

                        if (window.wireaderReadingMode !== 'paging') { return; }
                        if (window.wireaderUserGestureActive) {
                            window.wireaderDidScrollSinceTouch = true;
                        }
                        window.wireaderSchedulePageSettle();
                    }, { passive: true });
                }

                if (!window.wireaderTapListenerInstalled) {
                    window.wireaderTapListenerInstalled = true;
                    window.wireaderTapStart = null;
                    window.wireaderLastTapPostedAt = 0;
                    window.wireaderSuppressClickUntil = 0;

                    window.wireaderPostTap = function() {
                        var now = Date.now();
                        if (now - window.wireaderLastTapPostedAt < 500) { return; }
                        window.wireaderLastTapPostedAt = now;
                        window.webkit.messageHandlers.scrollProgress.postMessage('tap');
                    };

                    document.addEventListener('touchstart', function(event) {
                        if (event.touches.length !== 1) {
                            window.wireaderTapStart = null;
                            window.wireaderSuppressClickUntil = Date.now() + 1000;
                            window.wireaderUserGestureActive = false;
                            window.wireaderDidScrollSinceTouch = false;
                            window.wireaderTouchIsDown = false;
                            return;
                        }
                        var touch = event.touches[0];
                        window.wireaderUserGestureActive = true;
                        window.wireaderDidScrollSinceTouch = false;
                        window.wireaderTouchIsDown = true;
                        window.wireaderTapStart = {
                            x: touch.clientX,
                            y: touch.clientY,
                            t: Date.now()
                        };
                    }, { capture: true, passive: true });

                    document.addEventListener('touchend', function(event) {
                        var start = window.wireaderTapStart;
                        window.wireaderTapStart = null;
                        window.wireaderTouchIsDown = false;
                        if (!start || event.changedTouches.length !== 1) {
                            window.wireaderSuppressClickUntil = Date.now() + 1000;
                            return;
                        }

                        var touch = event.changedTouches[0];
                        var dx = Math.abs(touch.clientX - start.x);
                        var dy = Math.abs(touch.clientY - start.y);
                        var dt = Date.now() - start.t;
                        var selection = window.getSelection();
                        var hasSelection = selection && selection.toString().trim().length > 0;
                        var isTap = dx <= 10 && dy <= 10 && dt <= 350 && !hasSelection;

                        // WebKit may dispatch click after touchend even when the touch
                        // was a page swipe or long press. Handle touch taps here and
                        // suppress the synthetic click for every completed touch sequence.
                        window.wireaderSuppressClickUntil = Date.now() + 1000;
                        if (dx > 10 || dy > 10) {
                            window.wireaderDidScrollSinceTouch = true;
                        }
                        if (!window.wireaderDidScrollSinceTouch) {
                            window.wireaderUserGestureActive = false;
                        } else {
                            window.wireaderSchedulePageSettle();
                        }
                        if (isTap) {
                            window.wireaderPostTap();
                        }
                    }, { capture: true, passive: true });

                    document.addEventListener('click', function() {
                        if (Date.now() <= window.wireaderSuppressClickUntil) { return; }
                        window.wireaderPostTap();
                    }, { capture: true, passive: true });

                    document.addEventListener('touchcancel', function() {
                        window.wireaderTapStart = null;
                        window.wireaderTouchIsDown = false;
                        window.wireaderSuppressClickUntil = Date.now() + 1000;
                        if (window.wireaderDidScrollSinceTouch) {
                            window.wireaderSchedulePageSettle();
                        }
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
                        var position;
                        if (window.wireaderReadingMode === 'paging') {
                            var metrics = window.wireaderPagingMetrics();
                            if (metrics.maxPageIndex === 0) {
                                position = 0;
                            } else {
                                var anchorRange = range.cloneRange();
                                anchorRange.collapse(true);
                                var anchorRect = anchorRange.getBoundingClientRect();
                                var absoluteX = anchorRect.left + window.scrollX;

                                if (!Number.isFinite(absoluteX)) {
                                    position = window.wireaderCurrentPosition();
                                } else {
                                    var selectedPage = Math.floor(
                                        (Math.max(absoluteX, 0) + 0.5) / metrics.pageWidth
                                    );
                                    selectedPage = Math.min(
                                        Math.max(selectedPage, 0),
                                        metrics.maxPageIndex
                                    );
                                    position = selectedPage / metrics.maxPageIndex;
                                }
                            }
                        } else {
                            var rect = range.getBoundingClientRect();
                            var maxY = Math.max(document.body.scrollHeight - window.innerHeight, 1);
                            position = Math.min(Math.max((rect.top + window.scrollY) / maxY, 0), 1);
                        }
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
            webView.evaluateJavaScript(js) { [weak self, weak webView] _, error in
                if let error {
                    AppLogger.reader.error("didFinish JS: \(error.localizedDescription, privacy: .public)")
                }
                guard let self, let webView else { return }
                self.applyReadingMode(self.readingMode, to: webView) {
                    self.onPageLoaded()
                }
            }
            configureScrolling(for: readingMode, in: webView)
            applyTheme(to: webView)
        }

        func configureScrolling(for mode: ReaderReadingMode, in webView: WKWebView) {
            let scrollView = webView.scrollView
            scrollView.isPagingEnabled = mode == .paging
            scrollView.isDirectionalLockEnabled = mode == .paging
            scrollView.alwaysBounceHorizontal = mode == .paging
            scrollView.alwaysBounceVertical = mode == .scroll
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = mode == .scroll
        }

        func applyReadingMode(
            _ mode: ReaderReadingMode,
            to webView: WKWebView,
            completion: @escaping () -> Void = {}
        ) {
            let js: String
            switch mode {
            case .scroll:
                js = "window.wireaderSetReadingMode && window.wireaderSetReadingMode('scroll');"
            case .paging:
                js = "window.wireaderSetReadingMode && window.wireaderSetReadingMode('paging');"
            }
            webView.evaluateJavaScript(js) { _, error in
                if let error {
                    AppLogger.reader.error("EPUB reading mode JS: \(error.localizedDescription, privacy: .public)")
                }
                completion()
            }
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

        func restore(to position: Double, in webView: WKWebView) {
            let clampedPosition = min(max(position, 0.0), 1.0)
            let js = "window.wireaderRestorePosition && window.wireaderRestorePosition(\(clampedPosition));"
            webView.evaluateJavaScript(js) { _, error in
                if let error { AppLogger.reader.error("EPUB restore JS: \(error.localizedDescription, privacy: .public)") }
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
            } else if let payload = message.body as? [String: Any],
                      payload["type"] as? String == "pageSettled",
                      let position = (payload["position"] as? NSNumber)?.doubleValue {
                onProgressUpdate(position)
                if (payload["userInitiated"] as? NSNumber)?.boolValue == true {
                    onPageSettled(position)
                }
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
