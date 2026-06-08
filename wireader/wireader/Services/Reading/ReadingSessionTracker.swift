import Foundation

@Observable
final class ReadingSessionTracker {
    private(set) var currentSession: ReadingSession?
    private let repository: StatisticsRepository

    init(repository: StatisticsRepository) {
        self.repository = repository
    }

    func startSession(bookId: UUID) {
        let session = ReadingSession()
        session.bookId = bookId
        session.startTime = Date()
        currentSession = session
    }

    func endSession() {
        guard let session = currentSession else { return }
        session.endTime = Date()
        currentSession = nil
    }
}
