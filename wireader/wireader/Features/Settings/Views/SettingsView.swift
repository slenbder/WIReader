import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Внешний вид", destination: AppearanceSettingsView())
                NavigationLink("Подписка", destination: SubscriptionView())
            }
            .navigationTitle("Настройки")
        }
    }
}
