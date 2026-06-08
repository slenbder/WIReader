import SwiftUI
import WebKit

struct EPUBReaderView: UIViewRepresentable {
    let book: Book
    let viewModel: ReaderViewModel

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load current chapter file using loadFileURL
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let viewModel: ReaderViewModel
        init(viewModel: ReaderViewModel) { self.viewModel = viewModel }
    }
}
