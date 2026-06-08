import SwiftUI
import PDFKit

struct PDFReaderView: UIViewRepresentable {
    let book: Book
    let viewModel: ReaderViewModel

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Load PDF document
    }
}
