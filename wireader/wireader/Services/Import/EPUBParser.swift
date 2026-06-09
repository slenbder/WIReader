import Foundation
import ZIPFoundation

// MARK: - Errors

enum EPUBParserError: LocalizedError {
    case invalidFormat
    case missingContainerXML
    case missingOPF
    case corruptedSpine

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid EPUB format (not a ZIP archive)"
        case .missingContainerXML: return "Missing META-INF/container.xml"
        case .missingOPF: return "OPF package document not found"
        case .corruptedSpine: return "Corrupted or empty spine in OPF"
        }
    }
}

// MARK: - Parser

final class EPUBParser {

    func parse(_ epubURL: URL) async throws -> ParsedBook {
        let tmpDir = try makeTemp()

        do {
            try FileManager.default.unzipItem(at: epubURL, to: tmpDir)
        } catch {
            throw EPUBParserError.invalidFormat
        }

        // container.xml → OPF path
        let containerURL = tmpDir.appendingPathComponent("META-INF/container.xml")
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            throw EPUBParserError.missingContainerXML
        }
        let opfRelPath = try extractOPFPath(from: containerURL)

        let opfURL = tmpDir.appendingPathComponent(opfRelPath)
        guard FileManager.default.fileExists(atPath: opfURL.path) else {
            throw EPUBParserError.missingOPF
        }
        let opfDir = opfURL.deletingLastPathComponent()

        // OPF → metadata + manifest + spine
        let opf = try parseOPF(at: opfURL)
        guard !opf.spineRefs.isEmpty else {
            throw EPUBParserError.corruptedSpine
        }

        // TOC: EPUB 3 NAV first, fall back to EPUB 2 NCX
        var toc: [(href: String, title: String)] = []
        if let navHref = opf.navHref {
            toc = (try? parseNAV(at: opfDir.appendingPathComponent(navHref))) ?? []
        }
        if toc.isEmpty, let ncxHref = opf.ncxHref {
            toc = (try? parseNCX(at: opfDir.appendingPathComponent(ncxHref))) ?? []
        }

        // Build chapters in spine order
        let chapters: [EPUBChapter] = opf.spineRefs.enumerated().compactMap { idx, idref in
            guard let item = opf.manifest[idref] else { return nil }
            let title = matchTitle(for: item.href, in: toc) ?? "Chapter \(idx + 1)"
            return EPUBChapter(index: idx, title: title, fileURL: opfDir.appendingPathComponent(item.href))
        }

        let coverData = opf.coverHref.flatMap {
            try? Data(contentsOf: opfDir.appendingPathComponent($0))
        }

        return ParsedBook(
            title: opf.title.isEmpty ? "Unknown Title" : opf.title,
            author: opf.author,
            coverData: coverData,
            chapters: chapters,
            tempDir: tmpDir
        )
    }

    // MARK: - Private

    private func makeTemp() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.removeItem(at: dir)
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func extractOPFPath(from containerURL: URL) throws -> String {
        let data = try Data(contentsOf: containerURL)
        let handler = ContainerHandler()
        let p = XMLParser(data: data)
        p.delegate = handler
        p.parse()
        guard let path = handler.opfPath else { throw EPUBParserError.missingOPF }
        return path
    }

    private func parseOPF(at url: URL) throws -> OPFResult {
        let data = try Data(contentsOf: url)
        let handler = OPFHandler()
        let p = XMLParser(data: data)
        p.delegate = handler
        p.parse()
        return handler.result
    }

    private func parseNAV(at url: URL) throws -> [(href: String, title: String)] {
        let data = try Data(contentsOf: url)
        let handler = NAVHandler()
        let p = XMLParser(data: data)
        p.delegate = handler
        p.parse()
        return handler.entries
    }

    private func parseNCX(at url: URL) throws -> [(href: String, title: String)] {
        let data = try Data(contentsOf: url)
        let handler = NCXHandler()
        let p = XMLParser(data: data)
        p.delegate = handler
        p.parse()
        return handler.entries
    }

    private func matchTitle(for manifestHref: String, in toc: [(href: String, title: String)]) -> String? {
        if let exact = toc.first(where: { $0.href == manifestHref }) { return exact.title }
        let base = manifestHref.components(separatedBy: "/").last ?? manifestHref
        return toc.first(where: {
            ($0.href.components(separatedBy: "/").last ?? $0.href) == base
        })?.title
    }
}

// MARK: - OPF data types

private struct OPFResult {
    var title = ""
    var author: String?
    var manifest: [String: OPFItem] = [:]
    var spineRefs: [String] = []
    var coverHref: String?
    var navHref: String?
    var ncxHref: String?
}

private struct OPFItem {
    let href: String
    let mediaType: String
}

// MARK: - container.xml handler

private final class ContainerHandler: NSObject, XMLParserDelegate {
    var opfPath: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "rootfile", opfPath == nil {
            opfPath = attributes["full-path"]
        }
    }
}

// MARK: - OPF handler

private final class OPFHandler: NSObject, XMLParserDelegate {
    var result = OPFResult()

    private var section: String?
    private var buf = ""
    private var coverMetaID: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        buf = ""
        switch elementName {
        case "metadata": section = "metadata"
        case "manifest": section = "manifest"
        case "spine":    section = "spine"
        case "item" where section == "manifest":
            guard let id = attributes["id"], let href = attributes["href"] else { return }
            let mediaType = attributes["media-type"] ?? ""
            let props = attributes["properties"] ?? ""
            result.manifest[id] = OPFItem(href: href, mediaType: mediaType)
            if props.contains("cover-image") { result.coverHref = href }
            if props.contains("nav")          { result.navHref = href }
            if mediaType == "application/x-dtbncx+xml" { result.ncxHref = href }
        case "itemref" where section == "spine":
            if let idref = attributes["idref"] { result.spineRefs.append(idref) }
        case "meta" where section == "metadata":
            if attributes["name"] == "cover" { coverMetaID = attributes["content"] }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buf += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        defer { buf = "" }
        switch elementName {
        case "metadata", "manifest", "spine": section = nil
        case "dc:title" where section == "metadata":
            let t = buf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { result.title = t }
        case "dc:creator" where section == "metadata":
            let a = buf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !a.isEmpty { result.author = a }
        default: break
        }
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        if result.coverHref == nil, let id = coverMetaID,
           let item = result.manifest[id] {
            result.coverHref = item.href
        }
    }
}

// MARK: - EPUB 3 NAV handler

private final class NAVHandler: NSObject, XMLParserDelegate {
    var entries: [(href: String, title: String)] = []

    private var inTOC = false
    private var tocDepth = 0
    private var inAnchor = false
    private var pendingHref = ""
    private var buf = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        let name = elementName.lowercased()
        buf = ""
        if name == "nav" {
            if inTOC {
                tocDepth += 1
            } else {
                let epubType = attributes["epub:type"] ?? attributes["type"] ?? ""
                if epubType.contains("toc") { inTOC = true; tocDepth = 1 }
            }
        } else if name == "a" && inTOC, let href = attributes["href"] {
            inAnchor = true
            pendingHref = href.components(separatedBy: "#").first ?? href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inAnchor { buf += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if name == "a" && inAnchor {
            inAnchor = false
            let title = buf.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty && !pendingHref.isEmpty {
                entries.append((href: pendingHref, title: title))
            }
        }
        if name == "nav" && inTOC {
            tocDepth -= 1
            if tocDepth == 0 { inTOC = false }
        }
        buf = ""
    }
}

// MARK: - EPUB 2 NCX handler

private final class NCXHandler: NSObject, XMLParserDelegate {
    var entries: [(href: String, title: String)] = []

    private var inNavLabel = false
    private var inText = false
    private var pendingTitle = ""
    private var pendingHref = ""
    private var buf = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes: [String: String] = [:]) {
        let name = elementName.lowercased()
        buf = ""
        switch name {
        case "navlabel": inNavLabel = true
        case "text" where inNavLabel: inText = true
        case "content":
            if let src = attributes["src"] {
                pendingHref = src.components(separatedBy: "#").first ?? src
            }
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { buf += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        switch name {
        case "text" where inNavLabel:
            inText = false
            pendingTitle = buf.trimmingCharacters(in: .whitespacesAndNewlines)
        case "navlabel":
            inNavLabel = false
        case "navpoint":
            if !pendingTitle.isEmpty && !pendingHref.isEmpty {
                entries.append((href: pendingHref, title: pendingTitle))
            }
            pendingTitle = ""
            pendingHref = ""
        default: break
        }
        buf = ""
    }
}
