import SwiftUI

struct ReaderContainerView: View {
    let book: Book
    @State private var viewModel: ReaderViewModel
    @State private var showControls = true
    @Environment(\.dismiss) private var dismiss

    init(book: Book) {
        self.book = book
        self._viewModel = State(initialValue: ReaderViewModel(book: book))
    }

    var body: some View {
        ZStack {
            readerContent
            if showControls {
                ReaderControlsView(book: book, viewModel: viewModel, dismiss: { dismiss() })
            }
        }
        .ignoresSafeArea()
        .onTapGesture { showControls.toggle() }
    }

    @ViewBuilder
    private var readerContent: some View {
        switch book.format {
        case "epub":
            EPUBReaderView(book: book, viewModel: viewModel)
        case "pdf":
            PDFReaderView(book: book, viewModel: viewModel)
        default:
            TextReaderView(book: book, viewModel: viewModel)
        }
    }
}
