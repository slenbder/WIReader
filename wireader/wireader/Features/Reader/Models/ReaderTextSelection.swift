import Foundation

struct ReaderTextSelection: Identifiable, Equatable {
    let id = UUID()
    let selectedText: String
    let chapterIndex: Int
    let positionInChapter: Double

    init(selectedText: String, chapterIndex: Int, positionInChapter: Double) {
        self.selectedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.chapterIndex = chapterIndex
        self.positionInChapter = min(max(positionInChapter, 0.0), 1.0)
    }

    var isValid: Bool {
        !selectedText.isEmpty
    }
}
