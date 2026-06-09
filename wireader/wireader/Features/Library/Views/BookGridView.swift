import SwiftUI

struct BookGridView: View {
    let books: [Book]
    let onDelete: @MainActor (UUID) async -> Void

    init(books: [Book], onDelete: @MainActor @escaping (UUID) async -> Void = { _ in }) {
        self.books = books
        self.onDelete = onDelete
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books, id: \.id) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookCardView(book: book)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            let id = book.id
                            Task { @MainActor in await onDelete(id) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
}
