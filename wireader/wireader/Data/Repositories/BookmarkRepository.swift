import Foundation
import SwiftData

@MainActor
final class BookmarkRepository {

    func fetch(bookId: UUID, context: ModelContext) -> [Bookmark] {
        let id = bookId
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.bookId == id },
            sortBy: [SortDescriptor(\.dateCreated, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func add(
        book: Book,
        chapterIndex: Int,
        positionInChapter: Double,
        title: String?,
        context: ModelContext
    ) throws -> Bookmark {
        let bookmark = Bookmark()
        bookmark.bookId = book.id
        bookmark.chapterIndex = chapterIndex
        bookmark.positionInChapter = min(max(positionInChapter, 0.0), 1.0)
        bookmark.title = title
        bookmark.dateCreated = Date()

        context.insert(bookmark)
        book.bookmarks.append(bookmark)
        try context.save()
        return bookmark
    }

    func delete(_ bookmark: Bookmark, from book: Book, context: ModelContext) throws {
        book.bookmarks.removeAll { $0.id == bookmark.id }
        context.delete(bookmark)
        try context.save()
    }
}
