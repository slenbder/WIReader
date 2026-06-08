import SwiftUI
import UIKit

struct TextReaderView: UIViewRepresentable {
    let book: Book
    let viewModel: ReaderViewModel

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Load text content and apply theme
    }
}
