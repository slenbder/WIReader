import SwiftUI

struct BookDetailView: View {
    let book: Book
    @State private var isReading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(book.title).font(.title).bold()
                Text(book.author ?? "").foregroundStyle(.secondary)
                Button("Читать") { isReading = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(book.title)
        .fullScreenCover(isPresented: $isReading) {
            ReaderContainerView(book: book)
        }
    }
}
