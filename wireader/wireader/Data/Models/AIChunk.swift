import SwiftData
import Foundation

// ⚠️ Local-only: goes into localConfig (cloudKitDatabase: .none)
// Linked to Book via bookId — no @Relationship (different ModelConfiguration)
@Model class AIChunk {
    @Attribute(.unique) var id: UUID = UUID()
    var bookId: UUID = UUID()
    var chapterIndex: Int = 0
    var chunkIndex: Int = 0
    var text: String = ""

    init() {}
}
