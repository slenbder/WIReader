import SwiftData
import Foundation

@Model class Bookmark {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var positionInChapter: Double = 0.0
    var title: String? = nil
    var dateCreated: Date = Date()

    init() {}
}
