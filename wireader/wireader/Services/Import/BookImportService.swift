import Foundation
import SwiftData

@MainActor
final class BookImportService {
    private let fileStorage: FileStorageService
    private let epubParser = EPUBParser()

    init(fileStorage: FileStorageService) {
        self.fileStorage = fileStorage
    }

    func importBook(from url: URL, context: ModelContext) async throws -> Book {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "epub":
            return try await importEPUB(from: url, context: context)
        case "pdf", "txt", "fb2":
            return try await importPlain(from: url, format: ext, context: context)
        default:
            throw WIReaderError.unsupportedFormat
        }
    }

    // MARK: - Private

    private func importEPUB(from url: URL, context: ModelContext) async throws -> Book {
        let parsed = try await epubParser.parse(url)
        let fileName = try await fileStorage.save(from: url)

        let book = Book()
        book.title = parsed.title
        book.author = parsed.author
        book.format = "epub"
        book.fileName = fileName
        book.coverImageData = parsed.coverData
        book.dateAdded = Date()

        context.insert(book)
        try context.save()
        return book
    }

    private func importPlain(from url: URL, format: String, context: ModelContext) async throws -> Book {
        let fileName = try await fileStorage.save(from: url)

        let book = Book()
        book.title = url.deletingPathExtension().lastPathComponent
        book.author = nil
        book.format = format
        book.fileName = fileName
        book.coverImageData = nil
        book.dateAdded = Date()

        context.insert(book)
        try context.save()
        return book
    }
}
