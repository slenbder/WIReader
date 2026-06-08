import SwiftUI

struct ActivityGridView: View {
    let data: [Date: Int]
    private let columns = Array(repeating: GridItem(.fixed(12), spacing: 4), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(data.sorted(by: { $0.key < $1.key })), id: \.key) { entry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(entry.value > 0 ? Color.accentColor.opacity(Double(entry.value) / 10.0) : Color.secondary.opacity(0.15))
                    .frame(width: 12, height: 12)
            }
        }
    }
}
