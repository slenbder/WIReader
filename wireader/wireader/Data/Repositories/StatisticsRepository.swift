import SwiftData
import Foundation

@Observable
final class StatisticsRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchSessions(for bookId: UUID? = nil) throws -> [ReadingSession] {
        var descriptor = FetchDescriptor<ReadingSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchGoals() throws -> [ReadingGoal] {
        return try modelContext.fetch(FetchDescriptor<ReadingGoal>())
    }
}
