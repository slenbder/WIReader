import Foundation
import OSLog
import SwiftData

@MainActor
final class BookImportService {
    private let fileStorage: FileStorageService
    private let epubParser = EPUBParser()
    private let txtParser = TXTParser()
    private let fb2Parser = FB2Parser()

    init(fileStorage: FileStorageService) {
        self.fileStorage = fileStorage
    }

    func importBook(from url: URL, context: ModelContext) async throws -> Book {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "epub":
            return try await importEPUB(from: url, context: context)
        case "txt":
            return try await importParsed(txtParser.parse(url), from: url, format: ext, context: context)
        case "fb2":
            return try await importParsed(fb2Parser.parse(url), from: url, format: ext, context: context)
        case "pdf":
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

    private func importParsed(_ parsed: ParsedBook, from url: URL, format: String, context: ModelContext) async throws -> Book {
        let fileName = try await fileStorage.save(from: url)

        let book = Book()
        book.title = parsed.title
        book.author = parsed.author
        book.format = format
        book.fileName = fileName
        book.coverImageData = parsed.coverData
        book.dateAdded = Date()

        context.insert(book)
        try context.save()

        let chapterCount = parsed.chapters.count
        let preview: String
        if let first = parsed.chapters.first, case .plainText(let t) = first.content {
            preview = String(t.prefix(100))
        } else {
            preview = ""
        }
        AppLogger.general.info("Imported \(format): \"\(parsed.title)\" — \(chapterCount) chapters. Preview: \(preview)")

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
