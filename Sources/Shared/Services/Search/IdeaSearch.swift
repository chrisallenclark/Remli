import Foundation

/// Search that understands meaning as well as spelling.
///
/// "That thing about coffee shops" should find an idea that never used the word *coffee*,
/// while typing an exact project name should still put that project first. So both signals
/// run and the better one wins per result, rather than being averaged into mush.
enum IdeaSearch {

    struct Hit: Identifiable, Equatable {
        var id: UUID
        var score: Double
        /// True when the query literally appears in the idea. Used to justify a result
        /// that a semantic match alone would make look arbitrary.
        var isLiteral: Bool
    }

    /// Below this, a semantic match is noise rather than a result.
    private static let semanticFloor = 0.62

    struct Document: Sendable {
        var id: UUID
        var title: String
        var text: String
        var tags: [String]
        var categoryName: String?
        var embedding: [Float]?
    }

    static func rank(
        query: String,
        in documents: [Document],
        queryVector: [Float]?
    ) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        var hits: [Hit] = []

        for document in documents {
            let literal = literalScore(query: trimmed, document: document)

            var semantic = 0.0
            if let queryVector, let embedding = document.embedding, !embedding.isEmpty {
                let similarity = Similarity.cosine(queryVector, embedding)
                // Rescaled so that everything above the floor spreads across 0–1 instead
                // of bunching near the top of the cosine range.
                if similarity >= semanticFloor {
                    semantic = (similarity - semanticFloor) / (1 - semanticFloor)
                }
            }

            // Best-of rather than a blend: an exact title match should not be dragged down
            // by a mediocre vector score, and vice versa.
            let score = max(literal, semantic * 0.85)
            guard score > 0.05 else { continue }

            hits.append(Hit(id: document.id, score: score, isLiteral: literal > 0))
        }

        hits.sort { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.score > rhs.score
        }

        return hits
    }

    /// Weighted by where the match landed. A hit in the title means more than one buried
    /// in the body.
    private static func literalScore(query: String, document: Document) -> Double {
        let title = document.title.lowercased()
        let body = document.text.lowercased()

        if title == query { return 1.0 }
        if title.hasPrefix(query) { return 0.95 }
        if title.contains(query) { return 0.85 }

        if let category = document.categoryName?.lowercased(), category.contains(query) {
            return 0.7
        }

        for tag in document.tags where tag.lowercased().contains(query) {
            return 0.68
        }

        if body.contains(query) { return 0.6 }

        // Every word present somewhere, in any order — catches "coffee shop app" against
        // "an app for finding quiet coffee shops".
        let words = query.split(separator: " ").map(String.init).filter { $0.count > 2 }
        if words.count > 1 {
            let haystack = "\(title) \(body)"
            if words.allSatisfy({ haystack.contains($0) }) { return 0.55 }
        }

        return 0
    }
}

extension IdeaSearch.Document {
    init(_ idea: Idea) {
        self.id = idea.id
        self.title = idea.displayTitle
        self.text = idea.text
        self.tags = idea.tags
        self.categoryName = idea.category?.name
        self.embedding = idea.embedding.map(VectorCodec.decode)
    }
}
