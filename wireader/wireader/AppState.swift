import SwiftUI

@Observable
final class AppState {
    var isOnboardingComplete: Bool = UserDefaults.standard.bool(forKey: "isOnboardingComplete")
}
