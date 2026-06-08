import Foundation

enum ProgressCalculator {
    static func overall(chapterIndex: Int, positionInChapter: Double, totalChapters: Int) -> Double {
        guard totalChapters > 0 else { return 0 }
        let chapterProgress = Double(chapterIndex) / Double(totalChapters)
        let withinChapter = positionInChapter / Double(totalChapters)
        return min(chapterProgress + withinChapter, 1.0)
    }
}
