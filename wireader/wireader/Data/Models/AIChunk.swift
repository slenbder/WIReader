import SwiftData
import Foundation

// Local-only model — stored in separate ModelConfiguration without CloudKit
@Model class AIChunk {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var chunkIndex: Int = 0
    var text: String = ""

    init() {}
}
