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
        book.format = url.pathExtension.lowercased()
        book.title = url.deletingPathExtension().lastPathComponent
        book.fileName = try await fileStorage.save(from: url)
        Task.detached(priority: .background) {
            try await self.ragIndexer.index(book: book)
        }
        return book
    }
}
