import Foundation

@Observable
final class ReaderViewModel {
    let book: Book
    var currentChapterIndex: Int = 0
    var positionInChapter: Double = 0.0
    var overallProgress: Double = 0.0
    var chapters: [Chapter] = []

    init(book: Book) {
        self.book = book
        self.currentChapterIndex = book.progress?.chapterIndex ?? 0
        self.positionInChapter = book.progress?.positionInChapter ?? 0.0
        self.overallProgress = book.progress?.overallProgress ?? 0.0
    }

    func goToChapter(_ index: Int) {
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
