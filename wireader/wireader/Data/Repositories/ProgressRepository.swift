import SwiftData
import Foundation

@MainActor
final class ProgressRepository {

    func fetch(bookId: UUID, context: ModelContext) -> ReadingProgress? {
        let id = bookId
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.bookId == id }
        )
        return (try? context.fetch(descriptor))?.first
    }

    func save(progress: ReadingProgress, context: ModelContext) throws {
        context.insert(progress)
        try context.save()
    }

    func updateProgress(
        bookId: UUID,
        chapterIndex: Int,
        positionInChapter: Double,
        totalChapters: Int,
        context: ModelContext
    ) throws {
        let record = fetch(bookId: bookId, context: context) ?? {
            let r = ReadingProgress()
            r.bookId = bookId
            context.insert(r)
            return r
        }()
        record.chapterIndex = chapterIndex
        record.positionInChapter = positionInChapter
        record.overallProgress = ProgressCalculator.overallProgress(
            chapterIndex: chapterIndex,
            positionInChapter: positionInChapter,
            totalChapters: totalChapters
        )
        record.lastUpdated = Date()
        try context.save()
    }
}
