import Foundation

@Observable
final class LibraryViewModel {
    var books: [Book] = []
    var searchQuery: String = ""
    var isLoading: Bool = false
}
