import Foundation
import Observation
import OSLog
import WebKit
import SwiftData

@Observable
@MainActor
final class ReaderViewModel {

    var chapters: [BookChapter] = []
    var currentChapterIndex: Int = 0
    var tempDir: URL? = nil
    var pdfURL: URL? = nil
    var isLoading: Bool = false
    var error: Error? = nil
    var positionInChapter: Double = 0.0
    var overallProgress: Double = 0.0
    private(set) var restoreToken: Int = 0

    private(set) var webView: WKWebView?
    private var book: Book?
    private var lastProgressSave: Date = .distantPast
    private var pendingScrollPosition: Double?
    private let progressRepo = ProgressRepository()

    var currentChapter: BookChapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters[currentChapterIndex]
    }

    func load(book: Book, fileStorage: FileStorageService, context: ModelContext) async {
        isLoading = true
        error = nil
        self.book = book
        defer { isLoading = false }
        do {
            guard let fileURL = await fileStorage.url(for: book.fileName) else {
                throw WIReaderError.fileNotFound
            }

            if book.format == "pdf" {
                let savedPosition = min(max(progressRepo.fetch(bookId: book.id, context: context)?.positionInChapter ?? 0.0, 0.0), 1.0)
                positionInChapter = savedPosition
                pendingScrollPosition = nil
                overallProgress = savedPosition
                currentChapterIndex = 0
                restoreToken += 1
                chapters = []
                tempDir = nil
                pdfURL = fileURL
                return
            }

            let parsed: ParsedBook
            switch book.format {
            case "epub":
                parsed = try await EPUBParser().parse(fileURL)
            case "txt":
                parsed = try TXTParser().parse(fileURL)
            case "fb2":
                parsed = try FB2Parser().parse(fileURL)
            default:
                throw WIReaderError.parseError("Формат '\(book.format)' в разработке")
            }

            let saved = progressRepo.fetch(bookId: book.id, context: context)
            let restoredIndex = min(saved?.chapterIndex ?? 0, max(0, parsed.chapters.count - 1))
            let restoredPosition = saved?.positionInChapter ?? 0.0

            // Set position BEFORE chapters — @Observable coalesces these into one render,
            // guaranteeing TextReaderView's first render sees the correct scrollPosition.
            positionInChapter = restoredPosition
            pendingScrollPosition = restoredPosition
            overallProgress = ProgressCalculator.overallProgress(
                chapterIndex: restoredIndex,
                positionInChapter: restoredPosition,
                totalChapters: parsed.chapters.count
            )
            currentChapterIndex = restoredIndex
            restoreToken += 1
            chapters = parsed.chapters
            tempDir = parsed.tempDir
            pdfURL = nil
        } catch {
            self.error = error
        }
    }

    func goToNextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        // Position BEFORE index — same pattern as load(): guarantees updateUIView
        // sees scrollPosition=0 atomically with the new chapter text.
        positionInChapter = 0.0
        pendingScrollPosition = nil
        currentChapterIndex += 1
    }

    func goToPreviousChapter() {
        guard currentChapterIndex > 0 else { return }
        positionInChapter = 0.0
        pendingScrollPosition = nil
        currentChapterIndex -= 1
    }

    func goToChapter(_ index: Int) {
        guard index >= 0, index < chapters.count else { return }
        positionInChapter = 0.0
        pendingScrollPosition = nil
        currentChapterIndex = index
    }

    func setWebView(_ wv: WKWebView) {
        webView = wv
    }

    func applyPendingScroll() {
        guard let wv = webView, let pos = pendingScrollPosition else { return }
        // pendingScrollPosition kept set so window.load can re-apply after images load.
        // Cleared on chapter navigation (goTo* methods) to prevent stale re-apply.
        let js = "window.scrollTo(0,(document.body.scrollHeight-window.innerHeight)*\(pos));"
        wv.evaluateJavaScript(js) { _, error in
            if let error { AppLogger.reader.error("applyPendingScroll JS: \(error.localizedDescription, privacy: .public)") }
        }
    }

    /// Returns true when the position was actually persisted to SwiftData (throttle passed).
    @discardableResult
    func onScrollProgress(_ position: Double, context: ModelContext) -> Bool {
        positionInChapter = position
        overallProgress = ProgressCalculator.overallProgress(
            chapterIndex: currentChapterIndex,
            positionInChapter: position,
            totalChapters: progressUnitCount
        )
        let now = Date()
        guard now.timeIntervalSince(lastProgressSave) >= 2.0 else { return false }
        lastProgressSave = now
        guard let book else { return false }
        try? progressRepo.updateProgress(
            book: book,
            chapterIndex: currentChapterIndex,
            positionInChapter: position,
            totalChapters: progressUnitCount,
            context: context
        )
        return true
    }

    /// Writes positionInChapter immediately, bypassing the 2-second throttle.
    /// Call on dismiss and on scroll-end events so the last scroll position is never lost.
    func flushProgress(context: ModelContext) {
        lastProgressSave = Date()
        guard let book else { return }
        try? progressRepo.updateProgress(
            book: book,
            chapterIndex: currentChapterIndex,
            positionInChapter: positionInChapter,
            totalChapters: progressUnitCount,
            context: context
        )
    }

    private var progressUnitCount: Int {
        max(chapters.count, 1)
    }
}
