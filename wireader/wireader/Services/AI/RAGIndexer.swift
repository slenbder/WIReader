import Foundation

final class RAGIndexer {
    private let aiRepository: AIRepository
    private let epubParser: EPUBParser
    private let chunkSize = 300

    init(aiRepository: AIRepository, epubParser: EPUBParser) {
        self.aiRepository = aiRepository
        self.epubParser = epubParser
    }

    func index(book: Book) async throws {
        guard !book.isIndexed else { return }
        let chapters = try loadChapters(for: book)
        for (chapterIdx, chapter) in chapters.enumerated() {
            let text: String
            switch chapter.content {
            case .html(let fileURL):
                text = try String(contentsOf: fileURL, encoding: .utf8)
            case .plainText(let t):
                text = t
            }
            let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.isEmpty }
            var chunkIdx = 0
            var buffer = ""
            for paragraph in paragraphs {
                buffer += paragraph + "\n\n"
                if buffer.count >= chunkSize {
                    let chunk = AIChunk()
                    chunk.bookId = book.id
                    chunk.chapterIndex = chapterIdx
                    chunk.chunkIndex = chunkIdx
                    chunk.text = buffer
                    aiRepository.insertChunk(chunk)
                    buffer = ""
                    chunkIdx += 1
                }
            }
            if !buffer.isEmpty {
                let chunk = AIChunk()
                chunk.bookId = book.id
                chunk.chapterIndex = chapterIdx
                chunk.chunkIndex = chunkIdx
                chunk.text = buffer
                aiRepository.insertChunk(chunk)
            }
        }
        try aiRepository.save()
        book.isIndexed = true
    }

    private func loadChapters(for book: Book) throws -> [BookChapter] {
        // TODO(3.3): для .html извлекать чистый текст из HTML перед чанкингом — сырой String(contentsOf:) даёт один гигантский чанк с тегами
        return []
    }
}
