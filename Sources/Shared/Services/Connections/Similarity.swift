import Foundation

/// Pure similarity maths. No Apple frameworks beyond Foundation, so this is trivially
/// testable and has no device requirements.
enum Similarity {

    /// Cosine similarity, mapped from [-1, 1] to [0, 1] so it composes with the other
    /// signals without sign surprises.
    static func cosine(_ a: [Float], _ b: [Float]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }

        var dot: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        for index in a.indices {
            let x = Double(a[index])
            let y = Double(b[index])
            dot += x * y
            normA += x * x
            normB += y * y
        }

        guard normA > 0, normB > 0 else { return 0 }
        let raw = dot / (normA.squareRoot() * normB.squareRoot())
        return (raw + 1) / 2
    }

    /// Overlap of distinctive words, 0–1.
    ///
    /// Run alongside the vector score rather than instead of it. Embeddings catch "pitch
    /// deck" next to "investor slides"; word overlap catches proper nouns and coinages an
    /// embedding model has never seen — which, in a personal idea journal, is most of the
    /// interesting vocabulary.
    static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let intersection = a.intersection(b).count
        guard intersection > 0 else { return 0 }
        return Double(intersection) / Double(a.union(b).count)
    }

    /// The recall score. Weighted towards the embedding, with word overlap as a
    /// meaningful minority vote.
    static func hybrid(vector: Double, lexical: Double) -> Double {
        vector * 0.7 + lexical * 0.3
    }

    /// Words worth comparing: long enough to be distinctive, lowercased, deduplicated.
    static func significantWords(in text: String) -> Set<String> {
        var words = Set<String>()

        for token in text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            guard token.count >= 4, !stopWords.contains(String(token)) else { continue }
            words.insert(String(token))
        }

        return words
    }

    private static let stopWords: Set<String> = [
        "that", "this", "with", "from", "have", "when", "what", "would", "could",
        "should", "there", "their", "about", "which", "where", "then", "than",
        "some", "into", "over", "just", "like", "make", "made", "want", "need",
        "your", "them", "they", "were", "been", "more", "most", "very", "also",
        "thing", "things", "stuff", "idea", "ideas", "maybe", "really", "something",
    ]
}

/// Packs embeddings into `Data` for storage.
///
/// A 512-dimension vector as `[Double]` is 4KB per idea, which CloudKit would sync on
/// every change. Float32 halves that at no measurable cost to similarity ranking.
enum VectorCodec {

    static func encode(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.size
        guard count > 0 else { return [] }

        // Copied through a correctly aligned buffer rather than bound in place: `Data`
        // handed back by SwiftData carries no alignment guarantee, and binding a
        // misaligned pointer to Float is undefined behaviour.
        var vector = [Float](repeating: 0, count: count)
        vector.withUnsafeMutableBytes { destination in
            data.copyBytes(to: destination)
        }
        return vector
    }
}
