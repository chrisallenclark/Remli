import Foundation
import SwiftData

/// Owns the SwiftData stack.
///
/// CloudKit is not switched on yet — that needs entitlements and a container, which
/// arrive with the sync phase. The models are already written to CloudKit's rules though,
/// so turning it on later is a configuration change rather than a migration.
enum RemliSchema {

    static let schema = Schema([
        Idea.self,
        IdeaCategory.self,
        IdeaLink.self,
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Opens the real store, falling back to an in-memory one if that fails.
    ///
    /// A corrupt or unreadable store must not brick the app. Losing sync for a session is
    /// bad; refusing to launch at all is worse — especially for an app whose entire job is
    /// to be available the instant you have a thought.
    static func makeContainerWithFallback() -> (container: ModelContainer, isEphemeral: Bool) {
        do {
            return (try makeContainer(), false)
        } catch {
            #if DEBUG
            print("[Remli] Persistent store unavailable, falling back to memory: \(error)")
            #endif
            do {
                return (try makeContainer(inMemory: true), true)
            } catch {
                // An in-memory container cannot realistically fail. If it does, the
                // process is not in a state worth continuing in.
                fatalError("Unable to create even an in-memory model container: \(error)")
            }
        }
    }
}
