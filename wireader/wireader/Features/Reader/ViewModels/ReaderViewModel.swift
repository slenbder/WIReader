import Foundation
import Observation
import WebKit
import SwiftData

@Observable
@MainActor
final class ReaderViewModel {

    var chapters: [BookChapter] = []
    var currentChapterIndex: Int = 0
    var tempDir: URL? = nil
    var isLoading: Bool = false
    var error: Error? = nil
    var positionInChapter: Double = 0.0
    var overallProgress: Double = 0.0

    private(set) var webView: WKWebView?
    private var book: Book?
    private var lastProgressSave: Date = .distantPast
    private var pendingScrollPosition: Double?
    private let progressRepo = ProgressRepository()

    var currentChapter: BookChapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters[currentChapterIndex]
    }

    func load(book: Book, fileStorage: FileStorageService) async {
        isLoading = true
        error = nil
        self.book = book
        defer { isLoading = false }
        do {
            guard let fileURL = await fileStorage.url(for: book.fileName) else {
                throw WIReaderError.fileNotFound
            }
            let parsed = try await EPUBParser().parse(fileURL)
            chapters = parsed.chapters
            tempDir = parsed.tempDir
            currentChapterIndex = 0
        } catch let e {
            error = e
        }
    }

    func goToNextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        currentChapterIndex += 1
        positionInChapter = 0.0
    }

    func goToPreviousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
        positionInChapter = 0.0
    }

    func goToChapter(_ index: Int) {
        guard index >= 0, index < chapters.count else { return }
        currentChapterIndex = index
        positionInChapter = 0.0
    }

    func setWebView(_ wv: WKWebView) {
        webView = wv
    }

    func applyPendingScroll() {
        guard let wv = webView, let pos = pendingScrollPosition else { return }
        pendingScrollPosition = nil
        wv.evaluateJavaScript("window.scrollTo(0, (document.body.scrollHeight - window.innerHeight) * \(pos));")
    }

    func onScrollProgress(_ position: Double, context: ModelContext) {
        positionInChapter = position
        overallProgress = ProgressCalculator.overallProgress(
            chapterIndex: currentChapterIndex,
            positionInChapter: position,
            totalChapters: chapters.count
        )
        let now = Date()
        guard now.timeIntervalSince(lastProgressSave) >= 2.0 else { return }
        lastProgressSave = now
        guard let book else { return }
        try? progressRepo.updateProgress(
            book: book,
            chapterIndex: currentChapterIndex,
            positionInChapter: position,
            totalChapters: chapters.count,
            context: context
        )
    }

    func restoreProgress(for bookId: UUID, context: ModelContext) {
        guard let saved = progressRepo.fetch(bookId: bookId, context: context) else { return }
        pendingScrollPosition = saved.positionInChapter
        positionInChapter = saved.positionInChapter
        currentChapterIndex = saved.chapterIndex
    }
}
