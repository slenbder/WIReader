import Foundation

final class TXTParser {
    func parse(_ url: URL) throws -> [Chapter] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let chapter = Chapter(index: 0, title: url.deletingPathExtension().lastPathComponent, fileURL: url)
        return [chapter]
    }
}
