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
    var bookmarks: [Bookmark] = []
    var notes: [Note] = []
    private(set) var restoreToken: Int = 0

    private(set) var webView: WKWebView?
    private var book: Book?
    private var lastProgressSave: Date = .distantPast
    private var pendingScrollPosition: Double?
    private let progressRepo = ProgressRepository()
    private let bookmarkRepo = BookmarkRepository()
    private let noteRepo = NoteRepository()

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
                bookmarks = bookmarkRepo.fetch(bookId: book.id, context: context)
                notes = noteRepo.fetch(bookId: book.id, context: context)
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
            bookmarks = bookmarkRepo.fetch(bookId: book.id, context: context)
            notes = noteRepo.fetch(bookId: book.id, context: context)
            tempDir = parsed.tempDir
            pdfURL = nil
        } catch {
            self.error = error
        }
    }

    func goToNextChapter() {
        guard currentChapterIndex < chapters.count - 1 else { return }
        goToPosition(chapterIndex: currentChapterIndex + 1, positionInChapter: 0.0)
    }

    func goToPreviousChapter() {
        guard currentChapterIndex > 0 else { return }
        goToPosition(chapterIndex: currentChapterIndex - 1, positionInChapter: 0.0)
    }

    func goToChapter(_ index: Int) {
        goToPosition(chapterIndex: index, positionInChapter: 0.0)
    }

    func goToBookmark(_ bookmark: Bookmark) {
        goToPosition(
            chapterIndex: bookmark.chapterIndex,
            positionInChapter: bookmark.positionInChapter
        )
    }

    func goToNote(_ note: Note) {
        goToPosition(
            chapterIndex: note.chapterIndex,
            positionInChapter: note.positionInChapter
        )
    }

    func goToPosition(chapterIndex: Int, positionInChapter targetPosition: Double) {
        let clampedPosition = min(max(targetPosition, 0.0), 1.0)

        if chapters.isEmpty {
            guard pdfURL != nil else { return }
            positionInChapter = clampedPosition
            pendingScrollPosition = nil
            currentChapterIndex = 0
            overallProgress = clampedPosition
            restoreToken += 1
            return
        }

        guard chapterIndex >= 0, chapterIndex < chapters.count else { return }

        let previousChapterIndex = currentChapterIndex
        let shouldRestorePosition = clampedPosition > 0.0 || previousChapterIndex == chapterIndex

        // Position BEFORE index — same pattern as load(): guarantees renderers see
        // the target scroll position atomically with a chapter change.
        positionInChapter = clampedPosition
        pendingScrollPosition = shouldRestorePosition ? clampedPosition : nil
        overallProgress = ProgressCalculator.overallProgress(
            chapterIndex: chapterIndex,
            positionInChapter: clampedPosition,
            totalChapters: progressUnitCount
        )
        currentChapterIndex = chapterIndex

        if shouldRestorePosition {
            restoreToken += 1
        }
    }

    func setWebView(_ wv: WKWebView) {
        webView = wv
    }

    func prepareEPUBModeSwitch() {
        pendingScrollPosition = positionInChapter
    }

    func applyPendingEPUBPosition() {
        guard let wv = webView, let pos = pendingScrollPosition else { return }
        // pendingScrollPosition kept set so window.load can re-apply after images load.
        // Cleared on chapter navigation (goTo* methods) to prevent stale re-apply.
        let js = "window.wireaderRestorePosition && window.wireaderRestorePosition(\(pos));"
        wv.evaluateJavaScript(js) { _, error in
            if let error { AppLogger.reader.error("applyPendingEPUBPosition JS: \(error.localizedDescription, privacy: .public)") }
        }
    }

    func onEPUBPageSettled(_ position: Double, context: ModelContext) {
        let clampedPosition = min(max(position, 0.0), 1.0)
        // A completed user page flip is a discrete restore target, not a live mirror:
        // intermediate horizontal movement never mutates pendingScrollPosition.
        pendingScrollPosition = clampedPosition
        _ = onScrollProgress(clampedPosition, context: context)
        flushProgress(context: context)
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

    func loadBookmarks(context: ModelContext) {
        guard let book else { return }
        bookmarks = bookmarkRepo.fetch(bookId: book.id, context: context)
    }

    func addBookmark(context: ModelContext) {
        guard let book else { return }
        let title = bookmarkTitle()
        try? bookmarkRepo.add(
            book: book,
            chapterIndex: currentChapterIndex,
            positionInChapter: positionInChapter,
            title: title,
            context: context
        )
        loadBookmarks(context: context)
    }

    func deleteBookmark(_ bookmark: Bookmark, context: ModelContext) {
        guard let book else { return }
        try? bookmarkRepo.delete(bookmark, from: book, context: context)
        loadBookmarks(context: context)
    }

    func loadNotes(context: ModelContext) {
        guard let book else { return }
        notes = noteRepo.fetch(bookId: book.id, context: context)
    }

    @discardableResult
    func addNote(
        selectedText: String,
        noteText: String,
        chapterIndex: Int,
        positionInChapter: Double,
        context: ModelContext
    ) -> Bool {
        guard let book else { return false }
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty, !note.isEmpty else { return false }
        do {
            try noteRepo.add(
                book: book,
                chapterIndex: chapterIndex,
                positionInChapter: positionInChapter,
                selectedText: selected,
                noteText: note,
                context: context
            )
            loadNotes(context: context)
            return true
        } catch {
            context.rollback()
            AppLogger.reader.error("Add note failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @discardableResult
    func deleteNote(_ note: Note, context: ModelContext) -> Bool {
        guard let book else { return false }
        do {
            try noteRepo.delete(note, from: book, context: context)
            loadNotes(context: context)
            return true
        } catch {
            context.rollback()
            AppLogger.reader.error("Delete note failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private var progressUnitCount: Int {
        max(chapters.count, 1)
    }

    private func bookmarkTitle() -> String {
        let percent = Int((positionInChapter * 100).rounded())
        if chapters.isEmpty {
            return "PDF · \(percent)%"
        }

        let chapter = currentChapter?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = chapter?.isEmpty == false ? chapter! : "Глава \(currentChapterIndex + 1)"
        return "\(title) · \(percent)%"
    }
}
