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

    /// True when the process was launched by `xcodebuild test`.
    ///
    /// The unit tests are hosted by the app, so running them launches the real app, which
    /// opens the real store. That store is CloudKit-backed, and a simulator build signed
    /// with nothing has no `com.apple.developer.icloud-services` entitlement — CloudKit
    /// takes the process down during launch, before a single test can report. The tests
    /// then "fail" for reasons that have nothing to do with the code under test.
    ///
    /// Xcode sets `XCTestConfigurationFilePath` for the host process, which is the cheapest
    /// reliable signal available this early — `init()` runs before any test does, so
    /// nothing in the test bundle can be consulted.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

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
        // Under test the app is only a host: it exists so the bundle has something to load
        // into. Giving it an in-memory, CloudKit-free store keeps launch survivable and
        // guarantees a test run can never touch a real device's ideas.
        if isRunningTests {
            do {
                return (try makeContainer(inMemory: true), true)
            } catch {
                fatalError("Unable to create an in-memory container for testing: \(error)")
            }
        }

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
