import SwiftData
import SwiftUI

@main
struct RemliApp: App {

    private let container: ModelContainer
    private let isEphemeral: Bool

    init() {
        let result = RemliSchema.makeContainerWithFallback()
        self.container = result.container
        self.isEphemeral = result.isEphemeral

        // Skipped under test: the app is only acting as a host for the test bundle, and
        // BGTaskScheduler registration is a launch-time contract that has no meaning in a
        // process that exists to run assertions and exit.
        guard !RemliSchema.isRunningTests else { return }

        // Background task identifiers must be registered before launch finishes, so this
        // cannot wait for a view to appear. The handler builds its own coordinator rather
        // than capturing one, because no view exists yet at this point.
        let container = result.container
        ResurfacingCoordinator.registerBackgroundTask {
            await MainActor.run {
                let coordinator = ResurfacingCoordinator(
                    context: container.mainContext,
                    settingsStore: ResurfacingSettingsStore()
                )
                Task { await coordinator.refresh() }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(storeIsEphemeral: isEphemeral)
                .tint(Theme.Palette.ember)
        }
        .modelContainer(container)
    }
}
