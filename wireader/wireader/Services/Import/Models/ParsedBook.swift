import Foundation

struct ParsedBook {
    let title: String
    let author: String?
    let coverData: Data?
    let chapters: [EPUBChapter]
    let tempDir: URL
}
