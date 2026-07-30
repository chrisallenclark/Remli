import Foundation

/// What the intelligence layer works out about a captured thought.
///
/// Everything here is a *suggestion*. The idea itself is already saved by the time any of
/// this is computed, so a bad or missing enrichment degrades the experience without ever
/// costing the user their thought.
struct IdeaEnrichment: Equatable, Sendable {

    /// Whether this was a genuine idea or just a thing to do. Tasks skip the graph
    /// entirely — a to-do about calling the dentist would only add noise to it.
    var kind: IdeaKind

    /// A short noun phrase, not a sentence.
    var title: String

    /// Reused from the existing set where one fits, otherwise newly invented.
    var categoryName: String

    /// An SF Symbol name, constrained at generation time to a known-good list so the UI
    /// can never be handed a symbol that renders as blank.
    var categorySymbol: String

    var tags: [String]

    /// 0–1. Feeds the resurfacing score.
    var importance: Double

    /// Rough minutes of focused work, used to match an idea to a gap in the calendar.
    var estimatedMinutes: Int
}

protocol IdeaIntelligence: Sendable {

    /// Whether this implementation can currently do anything useful. A provider that
    /// returns false is skipped in favour of the next one.
    var isAvailable: Bool { get }

    /// Human-readable name, shown in Settings so it is never a mystery which engine
    /// produced a given result.
    var displayName: String { get }

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment
}

enum IntelligenceError: Error {
    case unavailable
    case emptyInput
    /// The model produced something structurally valid but semantically useless.
    case unusableResult
}

// MARK: - Layering

/// Tries each provider in order until one succeeds.
///
/// This is what makes "on-device by default, with a fallback" a property of the system
/// rather than something every call site has to remember. On a device without Apple
/// Intelligence the Foundation Models provider simply reports itself unavailable and the
/// heuristic one takes over, with no branching anywhere else in the app.
struct LayeredIntelligence: IdeaIntelligence {

    let providers: [any IdeaIntelligence]

    var isAvailable: Bool {
        providers.contains { $0.isAvailable }
    }

    var displayName: String {
        providers.first { $0.isAvailable }?.displayName ?? "Unavailable"
    }

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment {
        var lastError: Error = IntelligenceError.unavailable

        for provider in providers where provider.isAvailable {
            do {
                return try await provider.enrich(text: text, existingCategories: existingCategories)
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }
}
