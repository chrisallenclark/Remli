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

/// A flattened, `Sendable` view of an idea.
///
/// SwiftData models are not `Sendable` and are bound to their context, so the intelligence
/// layer is handed snapshots instead. It keeps the providers pure and free of any
/// knowledge of persistence.
struct IdeaSummary: Sendable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var excerpt: String

    /// The Space it lives in, when it has one. Cheap context that disambiguates a lot: a
    /// short idea named with a pun is unreadable on its own and obvious once you know it
    /// was filed under Business.
    var spaceName: String?

    /// The tags enrichment gave it — more of the same, for the same reason.
    var tags: [String]

    init(
        id: UUID,
        title: String,
        excerpt: String,
        spaceName: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.spaceName = spaceName
        self.tags = tags
    }

    /// `excerptLimit` defaults to enough for ranking, not enough for thinking.
    ///
    /// 220 characters is right for connection-finding, where the job is deciding whether
    /// two things are about the same subject and the opening sentence settles it. It is
    /// badly wrong for developing an idea, where the details further down are exactly what
    /// the model needs — pass a much larger limit there.
    init(_ idea: Idea, excerptLimit: Int = 220) {
        self.id = idea.id
        self.title = idea.displayTitle
        let body = idea.text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.excerpt = body.count <= excerptLimit ? body : String(body.prefix(excerptLimit)) + "…"
        self.spaceName = idea.category?.displayPath
        self.tags = idea.tags
    }
}

/// A connection the model believes exists, before it is written to the store.
struct ProposedLink: Sendable, Equatable {
    var targetID: UUID
    var kind: LinkKind
    /// One sentence saying *why*. Shown verbatim in the UI — a link without a convincing
    /// reason is worse than no link, because it teaches the user not to trust the feature.
    var rationale: String
    var strength: Double
}

/// One thing you could do next, and why it is worth doing.
struct DevelopmentStep: Sendable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    /// One sentence. A step without a reason is a chore someone else invented for you.
    var reason: String
}

/// What comes back from a working session on a single idea.
///
/// Two kinds of output, because they do different jobs. **Steps** are things to do, and are
/// only as good as the model's guess about your circumstances — it does not know you have
/// already registered the company. **Questions** make no assumptions at all; they are the
/// part that survives being wrong about you, and answering one turns it into a step you
/// wrote yourself.
struct IdeaDevelopment: Sendable, Equatable {

    /// The idea said back plainly. Ideas are captured at speed, often out loud, and reading
    /// a clean version of your own thought is the cheapest way to see what it actually was.
    var restatement: String

    var steps: [DevelopmentStep]

    /// Prompts, not rhetoric. Each should be answerable in a sentence and each answer
    /// should move the idea forward.
    var questions: [String]
}

protocol IdeaIntelligence: Sendable {

    /// Whether this implementation can currently do anything useful. A provider that
    /// returns false is skipped in favour of the next one.
    var isAvailable: Bool { get }

    /// Human-readable name, shown in Settings so it is never a mystery which engine
    /// produced a given result.
    var displayName: String { get }

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment

    /// Decides which of the shortlisted candidates genuinely relate to `source`, and says
    /// why. Returning an empty array is a valid and common answer.
    func judgeConnections(
        source: IdeaSummary,
        candidates: [IdeaSummary]
    ) async throws -> [ProposedLink]

    /// Works one idea forward: says it back plainly, proposes steps, and asks the
    /// questions that would unblock it.
    ///
    /// `related` is the person's own material — ideas already linked to this one. Passing
    /// it is what separates this from asking a chatbot for a project plan: the steps can
    /// refer to things they have actually thought of.
    func developIdea(_ idea: IdeaSummary, related: [IdeaSummary]) async throws -> IdeaDevelopment
}

extension IdeaIntelligence {

    /// Providers that cannot do this yet simply decline, and `LayeredIntelligence` moves on
    /// to the next one. Adding a capability to the protocol should never break a provider
    /// that has not implemented it — the layering exists precisely so capabilities can
    /// arrive unevenly.
    func developIdea(_ idea: IdeaSummary, related: [IdeaSummary]) async throws -> IdeaDevelopment {
        throw IntelligenceError.unavailable
    }
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

    func judgeConnections(
        source: IdeaSummary,
        candidates: [IdeaSummary]
    ) async throws -> [ProposedLink] {
        var lastError: Error = IntelligenceError.unavailable

        for provider in providers where provider.isAvailable {
            do {
                return try await provider.judgeConnections(source: source, candidates: candidates)
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    func developIdea(_ idea: IdeaSummary, related: [IdeaSummary]) async throws -> IdeaDevelopment {
        var lastError: Error = IntelligenceError.unavailable

        for provider in providers where provider.isAvailable {
            do {
                return try await provider.developIdea(idea, related: related)
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }
}
