import Foundation

@Observable
final class SettingsViewModel {
    @AppStorage("selectedThemeId") var selectedThemeId: String = "light"
    @AppStorage("fontSize") var fontSize: Double = 18
    @AppStorage("lineSpacing") var lineSpacing: Double = 1.4
}
