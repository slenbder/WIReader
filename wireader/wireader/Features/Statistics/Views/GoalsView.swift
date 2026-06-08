import SwiftUI

struct GoalsView: View {
    let goals: [ReadingGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Цели").font(.headline)
            ForEach(goals, id: \.id) { goal in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(goal.current) / \(goal.target) \(goal.type)")
                        Spacer()
                        Text("\(Int(Double(goal.current) / Double(goal.target) * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(goal.current), total: Double(goal.target))
                }
            }
        }
    }
}
