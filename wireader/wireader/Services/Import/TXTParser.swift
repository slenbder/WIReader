import Foundation

final class TXTParser {
    func parse(_ url: URL) throws -> [EPUBChapter] {
        let chapter = EPUBChapter(index: 0, title: url.deletingPathExtension().lastPathComponent, fileURL: url)
        return [chapter]
    }
}
