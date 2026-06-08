import Foundation

@Observable
final class BookDetailViewModel {
    var book: Book
    var progress: Double = 0.0

    init(book: Book) {
        self.book = book
        self.progress = book.progress?.overallProgress ?? 0.0
    }
}
