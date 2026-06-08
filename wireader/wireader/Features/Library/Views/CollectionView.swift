import SwiftUI

struct CollectionView: View {
    let collection: BookCollection

    var body: some View {
        BookGridView(books: collection.books)
            .navigationTitle(collection.name)
    }
}
