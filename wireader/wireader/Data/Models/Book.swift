import SwiftData
import Foundation

@Model class Book {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var author: String? = nil
    var format: String = "epub"
    var fileName: String = ""
    var coverImageData: Data? = nil
    var dateAdded: Date = Date()
    var lastReadDate: Date? = nil
    var tags: [String] = []
    var isIndexed: Bool = false

    @Relationship(deleteRule: .cascade) var progress: ReadingProgress?
    @Relationship(deleteRule: .cascade) var bookmarks: [Bookmark] = []
    @Relationship(deleteRule: .cascade) var notes: [Note] = []
    @Relationship(deleteRule: .cascade) var sessions: [ReadingSession] = []
    @Relationship(deleteRule: .cascade) var chapterSummaries: [ChapterSummary] = []
    var collection: BookCollection? = nil

    init() {}
}
