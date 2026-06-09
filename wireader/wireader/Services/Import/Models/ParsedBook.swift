import Foundation

struct ParsedBook {
    let title: String
    let author: String?
    let coverData: Data?
    let chapters: [BookChapter]
    let tempDir: URL?
}
