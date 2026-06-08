import SwiftData
import Foundation

@Model class ReadingGoal {
    @Attribute(.unique) var id: UUID = UUID()
    var year: Int = Calendar.current.component(.year, from: Date())
    var type: String = "books"
    var target: Int = 12
    var current: Int = 0

    init() {}
}
