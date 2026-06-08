import SwiftData
import Foundation

@Observable
final class ProgressRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func progress(for bookId: UUID) throws -> ReadingProgress? {
        let descriptor = FetchDescriptor<ReadingProgress>(
            predicate: #Predicate { $0.bookId == bookId }
        )
        return try modelContext.fetch(descriptor).first
    }

    func save() throws {
        try modelContext.save()
    }
}
