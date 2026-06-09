import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let chapterURL: URL
    let allowedDir: URL

    func makeUIView(context: Context) -> WKWebView {
        WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedURL != chapterURL else { return }
        context.coordinator.lastLoadedURL = chapterURL
        webView.loadFileURL(chapterURL, allowingReadAccessTo: allowedDir)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        var lastLoadedURL: URL?
    }
}
