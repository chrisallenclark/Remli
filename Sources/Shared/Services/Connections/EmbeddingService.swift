import Foundation
import NaturalLanguage

/// Turns an idea into a vector, for the cheap recall half of connection finding.
///
/// Uses `NLEmbedding`'s sentence embedding rather than `NLContextualEmbedding`. The
/// contextual model is better, but it needs downloadable assets and per-token mean
/// pooling, and this stage does not need to be good — it only has to get the right
/// handful of candidates into a shortlist that the language model then judges properly.
/// Precision is stage two's job.
final class EmbeddingService {

    private let embedding: NLEmbedding?

    /// Sentence embeddings degrade on long input, and the opening of a captured thought
    /// carries the substance. Truncating also keeps this fast enough to run inline.
    private static let maxCharacters = 400

    init(language: NLLanguage = .english) {
        self.embedding = NLEmbedding.sentenceEmbedding(for: language)
    }

    /// Whether vectors are available at all. When false the connection engine falls back
    /// to word overlap alone, which still finds obvious relationships.
    var isAvailable: Bool { embedding != nil }

    func vector(for text: String) -> [Float]? {
        guard let embedding else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let clipped = trimmed.count <= Self.maxCharacters
            ? trimmed
            : String(trimmed.prefix(Self.maxCharacters))

        guard let raw = embedding.vector(for: clipped) else { return nil }
        return raw.map(Float.init)
    }

    /// Embeds title and body together — the title is model-written and often carries the
    /// clearest statement of what the idea actually is.
    func vector(for idea: Idea) -> [Float]? {
        let combined = idea.title.isEmpty ? idea.text : "\(idea.title). \(idea.text)"
        return vector(for: combined)
    }
}
