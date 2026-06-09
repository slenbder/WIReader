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
