import Foundation
import Observation
import SwiftData

/// Applies enrichment to captured ideas, after the fact.
///
/// The ordering here is the app's central reliability guarantee: capture writes an `Idea`
/// and returns immediately, and this service comes along afterwards to fill in the title,
/// category, tags and estimates. Nothing the model does — or fails to do — can cost the
/// user a thought.
///
/// It also means enrichment is resumable. Ideas captured on a plane, or while Apple
/// Intelligence was still downloading, are simply picked up on a later launch.
@MainActor
@Observable
final class EnrichmentService {

    /// Give up after this many failures on the same idea. Without it, one pathological
    /// capture would be retried on every launch for the life of the app.
    private static let maxAttempts = 3

    private let context: ModelContext
    private let intelligence: any IdeaIntelligence
    private let embeddings: EmbeddingService

    private(set) var isWorking = false

    /// How many ideas are still waiting. Drives the subtle "Filing…" affordance.
    private(set) var pendingCount = 0

    init(
        context: ModelContext,
        intelligence: (any IdeaIntelligence)? = nil,
        embeddings: EmbeddingService = EmbeddingService()
    ) {
        self.context = context
        self.embeddings = embeddings
        self.intelligence = intelligence ?? LayeredIntelligence(providers: [
            FoundationModelsIntelligence(),
            HeuristicIntelligence(),
        ])
    }

    var engineName: String { intelligence.displayName }

    /// Explanation for why on-device enrichment isn't running, if it isn't. Nil when all
    /// is well. Surfaced in Settings so a device without Apple Intelligence says so rather
    /// than silently producing worse results.
    var degradedReason: String? {
        FoundationModelsIntelligence.unavailabilityReason
    }

    // MARK: - Running

    /// Processes every idea awaiting enrichment, oldest first.
    ///
    /// Serial by design. The on-device model is a single shared resource, so issuing
    /// concurrent requests would queue internally anyway while making failures harder to
    /// attribute.
    func run() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        while let idea = nextPending() {
            await enrich(idea)
            pendingCount = countPending()
        }
    }

    func refreshPendingCount() {
        pendingCount = countPending()
    }

    // MARK: - Internals

    private func pendingDescriptor(limit: Int?) -> FetchDescriptor<Idea> {
        let maxAttempts = Self.maxAttempts
        var descriptor = FetchDescriptor<Idea>(
            predicate: #Predicate { idea in
                !idea.isEnriched && idea.enrichmentAttempts < maxAttempts
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = limit
        return descriptor
    }

    private func nextPending() -> Idea? {
        (try? context.fetch(pendingDescriptor(limit: 1)))?.first
    }

    private func countPending() -> Int {
        (try? context.fetchCount(pendingDescriptor(limit: nil))) ?? 0
    }

    private func enrich(_ idea: Idea) async {
        // Recorded before the attempt, not after, so a crash mid-generation still counts
        // against the retry budget rather than looping forever.
        idea.enrichmentAttempts += 1

        do {
            let enrichment = try await intelligence.enrich(
                text: idea.text,
                existingCategories: existingCategoryNames()
            )
            apply(enrichment, to: idea)
        } catch {
            #if DEBUG
            print("[Remli] Enrichment failed for \(idea.id): \(error)")
            #endif
            // Deliberately silent. The idea is intact and readable; a banner about a
            // failed background nicety would be noise.
        }

        try? context.save()
    }

    private func apply(_ enrichment: IdeaEnrichment, to idea: Idea) {
        // Never clobber a title the user wrote themselves.
        if idea.title.isEmpty {
            idea.title = enrichment.title
        }

        idea.kind = enrichment.kind
        idea.tags = enrichment.tags
        idea.importanceScore = enrichment.importance
        idea.estimatedMinutes = enrichment.estimatedMinutes

        // Tasks stay out of the category system. They are transient by nature, and filing
        // them would clutter a set of categories meant to describe someone's thinking.
        if enrichment.kind == .idea {
            idea.category = resolveCategory(
                named: enrichment.categoryName,
                symbol: enrichment.categorySymbol
            )
        }

        // Computed here, while the title is fresh, so the connection engine never has to
        // stop and embed a backlog before it can rank anything.
        if let vector = embeddings.vector(for: idea) {
            idea.embedding = VectorCodec.encode(vector)
        }

        idea.isEnriched = true
        idea.touch()
    }

    // MARK: - Categories

    private func existingCategoryNames() -> [String] {
        let descriptor = FetchDescriptor<IdeaCategory>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return ((try? context.fetch(descriptor)) ?? []).map(\.name)
    }

    /// Finds the existing category or creates one.
    ///
    /// Matching is case- and whitespace-insensitive because the model will eventually
    /// return "business" where it once returned "Business", and two categories that read
    /// identically would be a bug the user could see.
    private func resolveCategory(named name: String, symbol: String) -> IdeaCategory {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let descriptor = FetchDescriptor<IdeaCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if let match = existing.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }) {
            return match
        }

        let category = IdeaCategory(name: name, symbolName: symbol)
        context.insert(category)
        return category
    }
}
