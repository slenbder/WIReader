import SwiftUI

struct BookGridView: View {
    let books: [Book]
    private let columns = [GridItem(.adaptive(minimum: 120))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(books, id: \.id) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        BookCardView(book: book)
                    }
                }
            }
            .padding()
        }
    }
}
