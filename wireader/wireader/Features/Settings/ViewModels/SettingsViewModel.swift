import Foundation

// @AppStorage is SwiftUI-only and incompatible with @Observable — use UserDefaults directly
@Observable
final class SettingsViewModel {
    var selectedThemeId: String = UserDefaults.standard.string(forKey: "selectedThemeId") ?? "light" {
        didSet { UserDefaults.standard.set(selectedThemeId, forKey: "selectedThemeId") }
    }
    var fontSize: Double = {
        let v = UserDefaults.standard.double(forKey: "fontSize"); return v == 0 ? 18 : v
    }() {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var lineSpacing: Double = {
        let v = UserDefaults.standard.double(forKey: "lineSpacing"); return v == 0 ? 1.4 : v
    }() {
        didSet { UserDefaults.standard.set(lineSpacing, forKey: "lineSpacing") }
    }
}
