import SwiftUI

struct ReaderControlsView: View {
    let book: Book
    let viewModel: ReaderViewModel
    let dismiss: () -> Void
    @State private var showSettings = false
    @State private var showTOC = false

    var body: some View {
        VStack {
            HStack {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                }
                Spacer()
                Text(book.title).font(.caption).lineLimit(1)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "textformat")
                }
                Button { showTOC = true } label: {
                    Image(systemName: "list.bullet")
                }
            }
            .padding()
            .background(.ultraThinMaterial)

            Spacer()

            ProgressView(value: viewModel.overallProgress)
                .padding(.horizontal)
                .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showSettings) { ReaderSettingsSheet() }
        .sheet(isPresented: $showTOC) { TableOfContentsView(viewModel: viewModel) }
    }
}
