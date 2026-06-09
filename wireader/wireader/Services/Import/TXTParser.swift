import Foundation

final class TXTParser {

    private let targetChapterSize = 15_000

    func parse(_ url: URL) throws -> ParsedBook {
        let data = try Data(contentsOf: url)
        let text = try decode(data)
        let title = url.deletingPathExtension().lastPathComponent
        let chapters = split(text)
        return ParsedBook(title: title, author: nil, coverData: nil, chapters: chapters, tempDir: nil)
    }

    // MARK: - Private

    private func decode(_ data: Data) throws -> String {
        if let s = String(data: data, encoding: .utf8) { return s }

        var converted: NSString?
        var usedLossy: ObjCBool = false
        let enc = NSString.stringEncoding(
            for: data,
            encodingOptions: [.allowLossyKey: false],
            convertedString: &converted,
            usedLossyConversion: &usedLossy
        )
        if enc != 0, let s = converted as String? { return s }

        if let s = String(data: data, encoding: .windowsCP1251) { return s }
        throw CocoaError(.fileReadUnknownStringEncoding)
    }

    private func split(_ text: String) -> [BookChapter] {
        guard text.count > targetChapterSize else {
            return [BookChapter(index: 0, title: nil, content: .plainText(text))]
        }

        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
        var chapters: [BookChapter] = []
        var buffer = ""

        for paragraph in paragraphs {
            if !buffer.isEmpty { buffer += "\n\n" }
            buffer += paragraph
            if buffer.count >= targetChapterSize {
                chapters.append(BookChapter(index: chapters.count, title: nil, content: .plainText(buffer)))
                buffer = ""
            }
        }
        if !buffer.isEmpty {
            chapters.append(BookChapter(index: chapters.count, title: nil, content: .plainText(buffer)))
        }
        return chapters.isEmpty ? [BookChapter(index: 0, title: nil, content: .plainText(text))] : chapters
    }
}
