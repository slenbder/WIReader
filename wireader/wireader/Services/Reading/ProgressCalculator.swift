import Foundation

enum ProgressCalculator {
    static func overallProgress(
        chapterIndex: Int,
        positionInChapter: Double,
        totalChapters: Int
    ) -> Double {
        guard totalChapters > 0 else { return 0 }
        let raw = (Double(chapterIndex) + positionInChapter) / Double(totalChapters)
        return min(max(raw, 0.0), 1.0)
    }
}
