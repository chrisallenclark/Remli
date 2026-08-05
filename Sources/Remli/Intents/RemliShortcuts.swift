import AppIntents
import Foundation
import SwiftData

/// "Hey Siri, add an idea to Remli: <something>"
///
/// Saves without opening the app. Unlike voice capture there is nothing to show — the text
/// already exists — and staying out of the way is the better experience.
///
/// App target only: it touches SwiftData, which the widget extension has no business
/// linking against.
struct AddIdeaIntent: AppIntent {

    static var title: LocalizedStringResource = "Add an idea"
    static var description = IntentDescription("Save an idea to Remli without opening it.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Idea", requestValueDialog: IntentDialog("What's the idea?"))
    var text: String

    init() {}

    init(text: String) {
        self.text = text
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "There was nothing to save.")
        }

        // Its own container: this runs outside the app's normal lifecycle, so there is no
        // context to borrow. Enrichment is left to the next launch, which keeps the same
        // save-first rule — the idea is safe even though it isn't filed yet.
        let container = try RemliSchema.makeContainer()
        let context = container.mainContext
        context.insert(Idea(text: trimmed, captureMode: .text))
        try context.save()

        return .result(dialog: "Saved.")
    }
}

/// Registers the spoken phrases. Without this the intents exist but Siri has nothing to
/// listen for.
struct RemliShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureIdeaIntent(),
            phrases: [
                "Capture an idea in \(.applicationName)",
                "New idea in \(.applicationName)",
            ],
            shortTitle: "Capture",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: AddIdeaIntent(),
            phrases: [
                "Add an idea to \(.applicationName)",
                "Remember this in \(.applicationName)",
            ],
            shortTitle: "Add idea",
            systemImageName: "lightbulb"
        )
    }
}
