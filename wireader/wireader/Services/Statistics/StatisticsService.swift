import Foundation

@Observable
final class StatisticsService {
    private let repository: StatisticsRepository

    init(repository: StatisticsRepository) {
        self.repository = repository
    }

    func weeklyReadingTime() throws -> [Date: TimeInterval] {
        let sessions = try repository.fetchSessions()
        var result: [Date: TimeInterval] = [:]
        let calendar = Calendar.current
        for session in sessions {
            guard let end = session.endTime else { continue }
            let day = calendar.startOfDay(for: session.startTime)
            result[day, default: 0] += end.timeIntervalSince(session.startTime)
        }
        return result
    }
}
