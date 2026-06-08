import Foundation

@Observable
final class StatisticsViewModel {
    var weeklyData: [Date: TimeInterval] = [:]
    var activityData: [Date: Int] = [:]
    var goals: [ReadingGoal] = []
}
