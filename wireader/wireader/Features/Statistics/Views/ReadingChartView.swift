import SwiftUI
import Charts

struct ReadingChartView: View {
    let data: [Date: TimeInterval]

    var body: some View {
        Chart(Array(data.sorted(by: { $0.key < $1.key })), id: \.key) { entry in
            BarMark(
                x: .value("День", entry.key, unit: .day),
                y: .value("Минуты", entry.value / 60)
            )
        }
        .frame(height: 150)
        .chartXAxis { AxisMarks(values: .stride(by: .day)) }
    }
}
