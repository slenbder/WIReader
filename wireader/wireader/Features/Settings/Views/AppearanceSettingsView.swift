import SwiftUI

struct AppearanceSettingsView: View {
    @AppStorage("selectedThemeId") private var selectedThemeId: String = "light"
    @AppStorage("fontSize") private var fontSize: Double = 18

    var body: some View {
        Form {
            Section("Тема") {
                Picker("Тема", selection: $selectedThemeId) {
                    Text("Светлая").tag("light")
                    Text("Тёмная").tag("dark")
                    Text("Сепия").tag("sepia")
                }
                .pickerStyle(.segmented)
            }
            Section("Шрифт") {
                Stepper("Размер: \(Int(fontSize))", value: $fontSize, in: 12...32)
            }
        }
        .navigationTitle("Внешний вид")
    }
}
