import SwiftUI
import SwiftData

@main
struct wireaderApp: App {
    let container: ModelContainer
    @State private var appState = AppState()

    init() {
        // TODO: switch to cloudKitDatabase: .automatic when Apple Developer enrollment is active
        let syncedConfig = ModelConfiguration(
            "Synced",
            schema: Schema([
                Book.self, ReadingProgress.self, Bookmark.self,
                Note.self, ReadingSession.self, ReadingGoal.self,
                BookCollection.self, ChapterSummary.self
            ]),
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "Local",
            schema: Schema([AIChunk.self]),
            cloudKitDatabase: .none
        )
        // All 9 models in `for:` ensures both configurations are registered;
        // each config's own schema controls which store each model routes to.
        do {
            container = try ModelContainer(
                for: Schema([
                    Book.self, ReadingProgress.self, Bookmark.self,
                    Note.self, ReadingSession.self, ReadingGoal.self,
                    BookCollection.self, ChapterSummary.self, AIChunk.self
                ]),
                configurations: [syncedConfig, localConfig]
            )
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if appState.isOnboardingComplete {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(container)
        .environment(appState)
    }
}
