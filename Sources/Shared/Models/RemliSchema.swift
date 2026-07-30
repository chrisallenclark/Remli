import Foundation
import SwiftData

/// Owns the SwiftData stack.
///
/// Backed by the user's own private CloudKit database, so ideas follow them across
/// devices and survive a lost phone without Remli running a server. Honouring CloudKit's
/// schema rules from the first commit — defaults everywhere, optional relationships with
/// inverses, no unique constraints — is what makes switching it on here a configuration
/// change rather than a migration.
enum RemliSchema {

    static let cloudKitContainerID = "iCloud.com.chrisallenclark.remli"

    static let schema = Schema([
        Idea.self,
        IdeaCategory.self,
        IdeaLink.self,
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            // In-memory stores are for previews and tests; pointing those at CloudKit
            // would try to sync throwaway fixture data into the user's real account.
            cloudKitDatabase: inMemory ? .none : .private(cloudKitContainerID)
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
