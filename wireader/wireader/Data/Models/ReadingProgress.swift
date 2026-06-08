import SwiftData
import Foundation

@Model class ReadingProgress {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var positionInChapter: Double = 0.0
    var overallProgress: Double = 0.0
    var lastUpdated: Date = Date()
    var isFinished: Bool = false

    init() {}
}
