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
    }

    var body: some Scene {
        WindowGroup {
            RootView(storeIsEphemeral: isEphemeral)
                .tint(Theme.Palette.ember)
        }
        .modelContainer(container)
    }
}
