import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Библиотека", systemImage: "books.vertical") }

            StatisticsView()
                .tabItem { Label("Статистика", systemImage: "chart.bar") }

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
    }
}
