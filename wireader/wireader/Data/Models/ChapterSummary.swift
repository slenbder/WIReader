import SwiftData
import Foundation

@Model class ChapterSummary {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var summaryText: String = ""
    var generatedAt: Date = Date()

    init() {}
}
