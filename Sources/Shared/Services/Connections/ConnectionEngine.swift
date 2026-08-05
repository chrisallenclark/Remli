import Foundation
import Observation
import SwiftData

/// Finds and explains relationships between ideas.
///
/// Two stages, and the split is what makes the feature affordable:
///
/// 1. **Recall** — embeddings and word overlap rank every other idea. Free, on-device,
///    instant, and crude.
/// 2. **Precision** — only the top dozen go to the language model, which decides which
///    are real, what kind of relationship each is, and writes the sentence explaining it.
///
/// Asking a model about every pair is O(n²): at 200 ideas that is roughly 20,000 model
/// calls for a single capture. This is O(n) cheap comparisons plus exactly one model call.
@MainActor
@Observable
final class ConnectionEngine {

    /// How many candidates survive recall and get judged properly.
    private static let shortlistSize = 12

    /// Below this the pair is not worth a model call.
    private static let minimumRecallScore = 0.55

    /// Links weaker than this are discarded even if the model proposed them. A visible
    /// wrong connection costs more trust than a missing one.
    private static let minimumLinkStrength = 0.25

    private static let maxAttempts = 3

    /// Only the most recent ideas are considered as candidates. Recall is linear, and
    /// beyond a few hundred the tail is almost never the interesting connection.
    private static let candidateWindow = 400

    private let context: ModelContext
    private let intelligence: any IdeaIntelligence
    private let embeddings: EmbeddingService

    private(set) var isWorking = false

    init(
        context: ModelContext,
        intelligence: (any IdeaIntelligence)? = nil,
        embeddings: EmbeddingService = EmbeddingService()
    ) {
        self.context = context
        self.embeddings = embeddings
        self.intelligence = intelligence ?? IntelligenceFactory.make()
    }

    // MARK: - Running

    /// Links every idea that has been enriched but never linked.
    ///
    /// Runs after enrichment rather than alongside it, because linking needs the title and
    /// category that enrichment produces.
    func run() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        while let idea = nextPending() {
            await connect(idea)
            try? context.save()
        }
    }

    private func nextPending() -> Idea? {
        let maxAttempts = Self.maxAttempts
        var descriptor = FetchDescriptor<Idea>(
            predicate: #Predicate { idea in
                idea.isEnriched && idea.linkedAt == nil && idea.linkAttempts < maxAttempts
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Connecting one idea

    func connect(_ idea: Idea) async {
        idea.linkAttempts += 1

        // Tasks stay out of the graph entirely. A reminder to call the dentist has no
        // business being connected to anything.
        guard idea.kind == .idea else {
            idea.linkedAt = .now
            return
        }

        let candidates = shortlist(for: idea)
        guard !candidates.isEmpty else {
            // Nothing to connect to yet — the first few ideas in a fresh library. Marked
            // as done regardless; a later capture will link back to this one.
            idea.linkedAt = .now
            return
        }

        do {
            let proposals = try await intelligence.judgeConnections(
                source: IdeaSummary(idea),
                candidates: candidates.map { IdeaSummary($0) }
            )
            apply(proposals, from: idea, candidates: candidates)
            idea.linkedAt = .now
        } catch {
            #if DEBUG
            print("[Remli] Link judging failed for \(idea.id): \(error)")
            #endif
            // Left unlinked so a later run can retry, up to the attempt budget.
        }
    }

    // MARK: - Stage one: recall

    private func shortlist(for idea: Idea) -> [Idea] {
        var descriptor = FetchDescriptor<Idea>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.candidateWindow

        let all = (try? context.fetch(descriptor)) ?? []
        let sourceID = idea.id
        let sourceWords = Similarity.significantWords(in: "\(idea.title) \(idea.text)")
        let sourceVector = vector(for: idea)

        let scored: [(idea: Idea, score: Double)] = all.compactMap { candidate in
            guard candidate.id != sourceID, candidate.kind == .idea else { return nil }

            let lexical = Similarity.jaccard(
                sourceWords,
                Similarity.significantWords(in: "\(candidate.title) \(candidate.text)")
            )

            var vectorScore = 0.0
            if let sourceVector, let candidateVector = vector(for: candidate) {
                vectorScore = Similarity.cosine(sourceVector, candidateVector)
            }

            // With no embeddings available at all, word overlap carries the whole score
            // rather than being diluted by a constant zero.
            let score = sourceVector == nil
                ? lexical
                : Similarity.hybrid(vector: vectorScore, lexical: lexical)

            guard score >= Self.minimumRecallScore else { return nil }
            return (candidate, score)
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(Self.shortlistSize)
            .map(\.idea)
    }

    /// Reads the stored vector, computing and caching it if enrichment did not.
    private func vector(for idea: Idea) -> [Float]? {
        if let data = idea.embedding {
            let decoded = VectorCodec.decode(data)
            if !decoded.isEmpty { return decoded }
        }

        guard let computed = embeddings.vector(for: idea) else { return nil }
        idea.embedding = VectorCodec.encode(computed)
        return computed
    }

    // MARK: - Stage two: writing links

    private func apply(_ proposals: [ProposedLink], from idea: Idea, candidates: [Idea]) {
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })

        // Existing links are keyed so a re-run cannot produce a visible duplicate. The key
        // sorts endpoints for undirected kinds, so A→B and B→A collapse to one.
        var existingKeys = Set(idea.allLinks.map(\.dedupeKey))

        for proposal in proposals {
            guard proposal.strength >= Self.minimumLinkStrength else { continue }
            guard let target = byID[proposal.targetID] else { continue }

            let link = IdeaLink(
                source: idea,
                target: target,
                kind: proposal.kind,
                rationale: proposal.rationale,
                strength: proposal.strength
            )

            guard existingKeys.insert(link.dedupeKey).inserted else { continue }
            context.insert(link)
        }
    }
}
