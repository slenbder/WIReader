import SwiftUI
import SwiftData

@main
struct wireaderApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let syncedSchema = Schema([
            Book.self, ReadingProgress.self, Bookmark.self,
            Note.self, ReadingSession.self, ReadingGoal.self,
            BookCollection.self, ChapterSummary.self
        ])
        let localSchema = Schema([AIChunk.self])

        let syncedConfig = ModelConfiguration(
            "Synced",
            schema: syncedSchema,
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "Local",
            schema: localSchema,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: syncedSchema, configurations: [syncedConfig, localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if appState.isOnboardingComplete {
                MainTabView()
                    .environment(appState)
            } else {
                OnboardingView()
                    .environment(appState)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
