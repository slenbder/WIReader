import SwiftUI

struct BookmarksPanelView: View {
    let bookmarks: [Bookmark]
    let onSelect: (Bookmark) -> Void

    var body: some View {
        NavigationStack {
            List(bookmarks, id: \.id) { bookmark in
                Button(bookmark.title ?? "Закладка") {
                    onSelect(bookmark)
                }
            }
            .navigationTitle("Закладки")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
