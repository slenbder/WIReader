import SwiftData
import Foundation

@Model class ReadingSession {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date? = nil
    var wordsRead: Int = 0
    var pagesRead: Int = 0

    init() {}
}
