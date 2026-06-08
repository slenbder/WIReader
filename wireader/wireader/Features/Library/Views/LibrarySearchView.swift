import SwiftUI

struct LibrarySearchView: View {
    @Binding var query: String
    let books: [Book]

    var filtered: [Book] {
        guard !query.isEmpty else { return books }
        return books.filter {
            $0.title.localizedStandardContains(query)
            || ($0.author ?? "").localizedStandardContains(query)
        }
    }

    var body: some View {
        List(filtered, id: \.id) { book in
            NavigationLink(destination: BookDetailView(book: book)) {
                VStack(alignment: .leading) {
                    Text(book.title).bold()
                    Text(book.author ?? "").foregroundStyle(.secondary).font(.caption)
                }
            }
        }
    }
}
