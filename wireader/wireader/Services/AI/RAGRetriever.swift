import Foundation

final class RAGRetriever {
    private let aiRepository: AIRepository
    private let topK = 15

    init(aiRepository: AIRepository) {
        self.aiRepository = aiRepository
    }

    func retrieve(query: String, bookId: UUID, chapterIndex: Int, positionInChapter: Double) throws -> String {
        let chunks = try aiRepository.chunks(forBookId: bookId, upToChapter: chapterIndex)
        let relevant = chunks
            .filter { $0.text.localizedStandardContains(query) }
            .suffix(topK)
        return relevant.map(\.text).joined(separator: "\n\n")
    }
}
