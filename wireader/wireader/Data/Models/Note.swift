import SwiftData
import Foundation

@Model class Note {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var positionInChapter: Double = 0.0
    var selectedText: String = ""
    var noteText: String = ""
    var dateCreated: Date = Date()

    init() {}
}
