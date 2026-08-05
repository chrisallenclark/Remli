import Foundation

/// Switches for work that has shipped in the binary but is not finished.
///
/// Remli reaches a real phone only through TestFlight, and every build costs an archive, an
/// upload and Apple's processing time. Long-lived branches are therefore the expensive
/// option here, not the safe one: they delay the moment anything can be tried on a device,
/// which is the only place this app can actually be judged. Flags let half-built work land
/// on `main`, ride along in a build, and stay invisible until it is ready.
///
/// Backed by `UserDefaults` rather than a compile-time condition so a flag can be flipped
/// from Settings on the device, without waiting fifteen minutes for another build.
///
/// **Every flag here is temporary.** A flag that outlives the work it was guarding becomes
/// a second code path nobody tests. Each one carries the phase that will delete it.
@Observable
final class FeatureFlags {

    /// Shared instance. Flags are read from view bodies and from services, and threading a
    /// store through both would be a lot of ceremony for a handful of booleans.
    static let shared = FeatureFlags()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Flags

    /// Phase 3 — connections are proposed and wait for approval instead of being written
    /// silently. Off means the current behaviour: the engine writes links as it finds them.
    var proposeConnections: Bool {
        get { defaults.bool(forKey: Key.proposeConnections) }
        set { defaults.set(newValue, forKey: Key.proposeConnections) }
    }

    // Phase 4's `spaceEnvironments` flag lived here and has been removed: the Space view
    // shipped, so the flag guarded nothing and only offered a way to turn a finished
    // feature off. A flag that outlives its work is a second code path nobody tests.

    /// Phase 6 — clustered Map with focus mode. Off keeps the force-directed graph that is
    /// on your phone today, which stays the fallback until the new one is verified on a
    /// real device with a real library.
    var clusteredMap: Bool {
        get { defaults.bool(forKey: Key.clusteredMap) }
        set { defaults.set(newValue, forKey: Key.clusteredMap) }
    }

    /// Turns everything off. The recovery path when an unfinished feature makes the app
    /// unusable and reinstalling would cost the local store.
    func resetAll() {
        proposeConnections = false
        clusteredMap = false
    }

    // MARK: - Keys

    /// Namespaced so a flag can never collide with the resurfacing settings, which share
    /// the same defaults domain.
    private enum Key {
        static let proposeConnections = "remli.flag.proposeConnections"
        static let clusteredMap = "remli.flag.clusteredMap"
    }
}
