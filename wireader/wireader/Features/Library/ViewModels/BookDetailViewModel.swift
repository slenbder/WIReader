import Foundation
import SwiftData

@Observable
@MainActor
final class BookDetailViewModel {
    var book: Book
    var isReaderOpen: Bool = false

    var progress: Double {
        book.progress?.overallProgress ?? 0
    }

    init(book: Book) {
        self.book = book
    }

    func deleteBook(context: ModelContext, fileStorage: FileStorageService) async throws {
        let repo = BookRepository(modelContext: context, fileStorage: fileStorage)
        try await repo.delete(book)
    }
}
