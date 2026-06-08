import Foundation

struct Chapter {
    let index: Int
    let title: String
    let fileURL: URL
}

final class EPUBParser {
    func unpack(_ epubURL: URL, bookId: UUID) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(bookId.uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        // ZIPFoundation unzip will be called here
        return tmpDir
    }

    func parseChapters(in bookDir: URL) throws -> [Chapter] {
        // Parse OPF manifest and NCX/NAV for chapter order
        return []
    }
}
