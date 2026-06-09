import Foundation

final class FB2Parser {

    func parse(_ url: URL) throws -> ParsedBook {
        let rawData = try Data(contentsOf: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent

        let handler = FB2Handler()
        if runParser(on: rawData, handler: handler) {
            return handler.build(fallbackTitle: fallbackTitle)
        }

        // libxml2 failed — re-encode to UTF-8 and rewrite XML declaration, then retry
        if let reencoded = reencodeToUTF8(rawData) {
            let retryHandler = FB2Handler()
            _ = runParser(on: reencoded, handler: retryHandler)
            return retryHandler.build(fallbackTitle: fallbackTitle)
        }

        return handler.build(fallbackTitle: fallbackTitle)
    }

    // MARK: - Private

    private func runParser(on data: Data, handler: FB2Handler) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = handler
        return parser.parse()
    }

    private func reencodeToUTF8(_ data: Data) -> Data? {
        let head = String(bytes: data.prefix(200), encoding: .ascii) ?? ""
        let ianaName = extractDeclaredEncoding(from: head)
        guard ianaName.uppercased() != "UTF-8" else { return nil }

        let cfEnc = CFStringConvertIANACharSetNameToEncoding(ianaName as CFString)
        guard cfEnc != kCFStringEncodingInvalidId else { return nil }
        let nsEnc = CFStringConvertEncodingToNSStringEncoding(cfEnc)
        guard let decoded = String(data: data, encoding: String.Encoding(rawValue: nsEnc)) else { return nil }

        let patched = decoded.replacingOccurrences(
            of: "encoding=\"\(ianaName)\"",
            with: "encoding=\"UTF-8\"",
            options: .caseInsensitive
        )
        return patched.data(using: .utf8)
    }

    private func extractDeclaredEncoding(from xmlHead: String) -> String {
        guard let range = xmlHead.range(of: #"encoding="([^"]+)""#, options: .regularExpression) else {
            return "UTF-8"
        }
        let parts = String(xmlHead[range]).components(separatedBy: "\"")
        return parts.count >= 2 ? parts[1] : "UTF-8"
    }
}

// MARK: - SAX handler

private final class FB2Handler: NSObject, XMLParserDelegate {

    // Extracted data
    private var bookTitle = ""
    private var authorFirstName = ""
    private var authorLastName = ""
    private(set) var coverData: Data?
    private(set) var chapters: [BookChapter] = []

    // Description/metadata state
    private var inDescription = false
    private var inTitleInfo = false
    private var inAuthor = false
    private var inCoverpage = false
    private var coverBinaryId: String?

    private var inBookTitle = false
    private var inFirstName = false
    private var inLastName = false
    private var metaBuf = ""

    // Body state
    private var bodyCount = 0
    private var sectionDepth = 0
    private var inSectionTitle = false
    private var inSectionTitleP = false
    private var inParagraph = false
    private var sectionTitleBuf = ""
    private var sectionTextBuf = ""

    // Binary cover buffering (only for the cover binary)
    private var collectingBinary = false
    private var binaryBuf = ""

    func build(fallbackTitle: String) -> ParsedBook {
        let title = bookTitle.isEmpty ? fallbackTitle : bookTitle
        let nameParts = [authorFirstName, authorLastName].filter { !$0.isEmpty }
        let author = nameParts.isEmpty ? nil : nameParts.joined(separator: " ")
        return ParsedBook(title: title, author: author, coverData: coverData, chapters: chapters, tempDir: nil)
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        let name = elementName.lowercased()

        switch name {
        case "description":
            inDescription = true
        case "title-info" where inDescription:
            inTitleInfo = true
        case "author" where inTitleInfo:
            inAuthor = true
        case "book-title" where inTitleInfo:
            inBookTitle = true; metaBuf = ""
        case "first-name" where inAuthor:
            inFirstName = true; metaBuf = ""
        case "last-name" where inAuthor:
            inLastName = true; metaBuf = ""
        case "coverpage" where inTitleInfo:
            inCoverpage = true
        case "image" where inCoverpage:
            let href = attributes["href"] ?? attributes["l:href"] ?? ""
            if href.hasPrefix("#") { coverBinaryId = String(href.dropFirst()) }
        case "binary":
            let binaryId = attributes["id"] ?? ""
            if let coverId = coverBinaryId, binaryId == coverId {
                collectingBinary = true; binaryBuf = ""
            }
        case "body":
            bodyCount += 1
        case "section" where bodyCount == 1:
            sectionDepth += 1
            if sectionDepth == 1 { sectionTitleBuf = ""; sectionTextBuf = "" }
        case "title" where bodyCount == 1 && sectionDepth == 1:
            inSectionTitle = true
        case "p" where bodyCount == 1 && sectionDepth >= 1:
            if inSectionTitle { inSectionTitleP = true }
            else { inParagraph = true }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if collectingBinary { binaryBuf += string; return }
        if inBookTitle { metaBuf += string; return }
        if inFirstName { metaBuf += string; return }
        if inLastName { metaBuf += string; return }
        if inSectionTitleP { sectionTitleBuf += string; return }
        if inParagraph && bodyCount == 1 { sectionTextBuf += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()

        switch name {
        case "description":
            inDescription = false
        case "title-info":
            inTitleInfo = false
        case "author":
            inAuthor = false
        case "book-title":
            inBookTitle = false
            let t = metaBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { bookTitle = t }
        case "first-name":
            inFirstName = false
            let t = metaBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && authorFirstName.isEmpty { authorFirstName = t }
        case "last-name":
            inLastName = false
            let t = metaBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty && authorLastName.isEmpty { authorLastName = t }
        case "coverpage":
            inCoverpage = false
        case "binary":
            if collectingBinary {
                let cleaned = binaryBuf.filter { !$0.isWhitespace }
                coverData = Data(base64Encoded: cleaned)
                collectingBinary = false
            }
        case "p":
            guard bodyCount == 1 && sectionDepth >= 1 else { break }
            if inSectionTitleP {
                inSectionTitleP = false
            } else if inParagraph {
                inParagraph = false
                if !sectionTextBuf.isEmpty { sectionTextBuf += "\n\n" }
            }
        case "title":
            guard bodyCount == 1 && sectionDepth == 1 else { break }
            inSectionTitle = false
        case "section":
            guard bodyCount == 1 else { break }
            if sectionDepth == 1 {
                let chapterTitle = sectionTitleBuf.trimmingCharacters(in: .whitespacesAndNewlines)
                let text = sectionTextBuf.trimmingCharacters(in: .whitespacesAndNewlines)
                chapters.append(BookChapter(
                    index: chapters.count,
                    title: chapterTitle.isEmpty ? nil : chapterTitle,
                    content: .plainText(text)
                ))
            }
            sectionDepth = max(0, sectionDepth - 1)
        default:
            break
        }
    }
}
