import Foundation
import Observation

/// User-controlled settings for the optional Claude provider.
///
/// The API key itself lives in the Keychain, not here — this only tracks whether the
/// feature is on and which model to use.
@MainActor
@Observable
final class ClaudeSettingsStore {

    /// Shared because both the enrichment service and the connection engine need to build
    /// providers from the same state, and they are created independently.
    static let shared = ClaudeSettingsStore()

    private static let enabledKey = "remli.claude.enabled"
    private static let modelKey = "remli.claude.model"

    private let defaults: UserDefaults

    /// Off until the user passes through the consent screen. Never defaults to true.
    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Self.enabledKey)
        }
    }

    var model: ClaudeModel {
        didSet {
            guard model != oldValue else { return }
            defaults.set(model.rawValue, forKey: Self.modelKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledKey)
        self.model = ClaudeModel(rawValue: defaults.string(forKey: Self.modelKey) ?? "") ?? .opus
    }

    /// True only when the user consented *and* a key is actually present. Both are
    /// required — a stale enabled flag with no key would silently do nothing.
    var isActive: Bool { isEnabled && KeychainStore.hasKey }

    /// Turning the feature off removes the key as well. Leaving a credential behind for a
    /// feature the user just switched off is not a defensible default.
    func disableAndForgetKey() {
        isEnabled = false
        KeychainStore.delete()
    }
}

/// Builds the provider chain.
///
/// Ordering is the whole point: Claude first *if* the user turned it on, then Apple's
/// on-device model, then the heuristic floor. Because `LayeredIntelligence` falls through
/// on any thrown error, a network failure or a rate limit degrades to on-device
/// enrichment automatically rather than losing the idea's metadata.
enum IntelligenceFactory {

    @MainActor
    static func make(settings: ClaudeSettingsStore = .shared) -> any IdeaIntelligence {
        var providers: [any IdeaIntelligence] = []

        if settings.isActive {
            providers.append(ClaudeIntelligence(model: settings.model))
        }

        providers.append(FoundationModelsIntelligence())
        providers.append(HeuristicIntelligence())

        return LayeredIntelligence(providers: providers)
    }
}
