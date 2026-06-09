import Foundation
import SwiftData

@MainActor
@Observable
final class LibraryViewModel {
    var searchQuery: String = ""
    var isLoading: Bool = false
    var importError: Error?
    var isShowingError: Bool = false

    private let importService = BookImportService(fileStorage: FileStorageService())

    func deleteBook(id: UUID, books: [Book], context: ModelContext) async {
        guard let book = books.first(where: { $0.id == id }) else { return }
        let repo = BookRepository(modelContext: context, fileStorage: FileStorageService())
        do {
            try await repo.delete(book)
        } catch {
            importError = error
            isShowingError = true
        }
    }

    func importBook(from url: URL, context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await importService.importBook(from: url, context: context)
        } catch {
            importError = error
            isShowingError = true
        }
    }
}
