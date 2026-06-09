import SwiftData
import Foundation

@MainActor
final class BookRepository {
    private let modelContext: ModelContext
    private let fileStorage: FileStorageService

    init(modelContext: ModelContext, fileStorage: FileStorageService) {
        self.modelContext = modelContext
        self.fileStorage = fileStorage
    }

    func delete(_ book: Book) async throws {
        try await fileStorage.delete(fileName: book.fileName)
        modelContext.delete(book)
        try modelContext.save()
    }

    func fetch(by id: UUID) -> Book? {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func search(query: String) -> [Book] {
        guard !query.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { book in
                book.title.localizedStandardContains(query) ||
                book.author?.localizedStandardContains(query) == true
            },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
