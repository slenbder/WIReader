import Foundation
import Observation

@Observable
@MainActor
final class ReaderViewModel {

    var chapters: [EPUBChapter] = []
    var currentChapterIndex: Int = 0
    var tempDir: URL? = nil
    var isLoading: Bool = false
    var error: Error? = nil

    // Kept for Phase 2 (ReaderControlsView, progress tracking)
    var positionInChapter: Double = 0.0
    var overallProgress: Double = 0.0

    var currentChapter: EPUBChapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters[currentChapterIndex]
    }

    func load(book: Book, fileStorage: FileStorageService) async {
        isLoading = true
        error = nil
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
    }

    func goToPreviousChapter() {
        guard currentChapterIndex > 0 else { return }
        currentChapterIndex -= 1
    }

    // Used by TableOfContentsView
    func goToChapter(_ index: Int) {
        guard index >= 0, index < chapters.count else { return }
        currentChapterIndex = index
        positionInChapter = 0.0
    }

    func updateProgress(position: Double) {
        positionInChapter = position
        overallProgress = ProgressCalculator.overall(
            chapterIndex: currentChapterIndex,
            positionInChapter: positionInChapter,
            totalChapters: chapters.count
        )
    }
}
