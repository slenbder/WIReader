import SwiftUI

struct StatisticsView: View {
    @State private var viewModel = StatisticsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ReadingChartView(data: viewModel.weeklyData)
                    ActivityGridView(data: viewModel.activityData)
                    GoalsView(goals: viewModel.goals)
                }
                .padding()
            }
            .navigationTitle("Статистика")
        }
    }
}
