import SwiftData
import Foundation

@Observable
final class AIRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func chunks(forBookId bookId: UUID, upToChapter chapterIndex: Int) throws -> [AIChunk] {
        let descriptor = FetchDescriptor<AIChunk>(
            predicate: #Predicate { $0.bookId == bookId && $0.chapterIndex <= chapterIndex },
            sortBy: [SortDescriptor(\.chapterIndex), SortDescriptor(\.chunkIndex)]
        )
        return try modelContext.fetch(descriptor)
    }

    func insertChunk(_ chunk: AIChunk) {
        modelContext.insert(chunk)
    }

    func deleteChunks(forBookId bookId: UUID) throws {
        let chunks = try modelContext.fetch(
            FetchDescriptor<AIChunk>(predicate: #Predicate { $0.bookId == bookId })
        )
        chunks.forEach { modelContext.delete($0) }
    }

    func save() throws {
        try modelContext.save()
    }
}
