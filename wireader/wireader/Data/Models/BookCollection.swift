import SwiftData
import Foundation

@Model class BookCollection {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#5B7FA6"
    var dateCreated: Date = Date()
    @Relationship var books: [Book] = []

    init() {}
}
