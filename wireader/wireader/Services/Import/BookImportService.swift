import Foundation

final class BookImportService {
    private let fileStorage: FileStorageService
    private let ragIndexer: RAGIndexer

    init(fileStorage: FileStorageService, ragIndexer: RAGIndexer) {
        self.fileStorage = fileStorage
        self.ragIndexer = ragIndexer
    }

    func importBook(from url: URL) async throws -> Book {
        let book = Book()
        book.fileName = url.lastPathComponent
        book.format = url.pathExtension.lowercased()
        book.title = url.deletingPathExtension().lastPathComponent
        try await fileStorage.copyToiCloud(url, bookId: book.id)
        Task.detached(priority: .background) {
            try await self.ragIndexer.index(book: book)
        }
        return book
    }
}
