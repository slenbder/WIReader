import SwiftUI

struct BookmarksPanelView: View {
    let bookmarks: [Bookmark]
    let onSelect: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView(
                        "Нет закладок",
                        systemImage: "bookmark",
                        description: Text("Добавьте закладку из панели чтения.")
                    )
                } else {
                    List {
                        ForEach(bookmarks, id: \.id) { bookmark in
                            Button {
                                onSelect(bookmark)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title ?? "Закладка")
                                        .foregroundStyle(.primary)

                                    Text(bookmark.dateCreated.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            offsets.map { bookmarks[$0] }.forEach(onDelete)
                        }
                    }
                }
            }
            .navigationTitle("Закладки")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
