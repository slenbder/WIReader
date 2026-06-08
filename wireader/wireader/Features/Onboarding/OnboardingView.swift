import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Text("Добро пожаловать в WIReader")
                .font(.largeTitle).bold()
            Text("Читайте книги умнее с AI-помощником")
                .foregroundStyle(.secondary)
            Button("Начать") {
                UserDefaults.standard.set(true, forKey: "isOnboardingComplete")
                appState.isOnboardingComplete = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
