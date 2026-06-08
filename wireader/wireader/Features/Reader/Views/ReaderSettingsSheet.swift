import SwiftUI

struct ReaderSettingsSheet: View {
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("lineSpacing") private var lineSpacing: Double = 1.4
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "light"

    var body: some View {
        NavigationStack {
            Form {
                Section("Шрифт") {
                    Slider(value: $fontSize, in: 12...32, step: 1) {
                        Text("Размер: \(Int(fontSize))")
                    }
                }
                Section("Межстрочный интервал") {
                    Slider(value: $lineSpacing, in: 1.0...2.0, step: 0.1) {
                        Text("Интервал: \(String(format: "%.1f", lineSpacing))")
                    }
                }
            }
            .navigationTitle("Настройки чтения")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
