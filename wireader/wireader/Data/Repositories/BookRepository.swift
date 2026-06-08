import SwiftData
import Foundation

@Observable
final class BookRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [Book] {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        return try modelContext.fetch(descriptor)
    }

    func insert(_ book: Book) {
        modelContext.insert(book)
    }

    func delete(_ book: Book) {
        modelContext.delete(book)
    }

    func save() throws {
        try modelContext.save()
    }
}
