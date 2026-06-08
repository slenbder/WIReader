import Foundation

final class FileStorageService {
    func iCloudBooksURL() -> URL? {
        FileManager.default.url(
            forUbiquityContainerIdentifier: AppConstants.iCloudContainerID
        )?.appendingPathComponent("Books")
    }

    func copyToiCloud(_ sourceURL: URL, bookId: UUID) async throws {
        guard let booksURL = iCloudBooksURL() else {
            throw WIReaderError.storageError("iCloud container not available")
        }
        try FileManager.default.createDirectory(at: booksURL, withIntermediateDirectories: true)
        let destination = booksURL.appendingPathComponent("\(bookId).\(sourceURL.pathExtension)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
    }

    func localURL(for book: Book) -> URL? {
        iCloudBooksURL()?.appendingPathComponent(book.fileName)
    }
}
