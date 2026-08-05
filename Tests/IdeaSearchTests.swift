import Foundation
import Testing

@testable import Remli

/// Finding an idea you half-remember.
///
/// The rule these protect: **exact search must never get worse.** A semantic layer that
/// buries a literal title match under something merely similar is a downgrade dressed up
/// as intelligence, and it is the failure mode users notice immediately and never forgive.
@Suite("Search")
struct IdeaSearchTests {

    private func document(
        title: String,
        text: String,
        tags: [String] = [],
        space: String? = nil,
        embedding: [Float]? = nil
    ) -> IdeaSearch.Document {
        IdeaSearch.Document(
            id: UUID(),
            title: title,
            text: text,
            tags: tags,
            categoryName: space,
            embedding: embedding
        )
    }

    @Test("An exact title match ranks first and says so")
    func exactTitleWins() {
        let target = document(title: "Client tracking app", text: "For personal trainers")
        let other = document(title: "Something else entirely", text: "Client tracking gets a mention here")

        let hits = IdeaSearch.rank(query: "Client tracking app", in: [other, target], queryVector: nil)

        #expect(hits.first?.id == target.id)
        #expect(hits.first?.reason == .title)
        #expect(hits.first?.isLiteral == true)
    }

    @Test("A match in the body is reported as a body match, not a title one")
    func bodyMatchIsHonest() {
        let doc = document(title: "Untitled", text: "An idea about packaging for the meal prep business")
        let hits = IdeaSearch.rank(query: "packaging", in: [doc], queryVector: nil)

        #expect(hits.count == 1)
        #expect(hits.first?.reason == .body)
    }

    @Test("A tag match is reported as a tag match")
    func tagMatch() {
        let doc = document(title: "Cocktail bar", text: "Weddings and events", tags: ["bartending"])
        let hits = IdeaSearch.rank(query: "bartending", in: [doc], queryVector: nil)

        #expect(hits.first?.reason == .tag)
    }

    @Test("A Space name match is reported as a Space match")
    func spaceMatch() {
        let doc = document(title: "Supplier list", text: "Nothing relevant", space: "Macrova")
        let hits = IdeaSearch.rank(query: "macrova", in: [doc], queryVector: nil)

        #expect(hits.first?.reason == .space)
    }

    /// The point of semantic search: finding something that shares none of your words.
    @Test("A purely semantic hit is labelled as meaning, not invented word overlap")
    func semanticMatchIsLabelledHonestly() {
        let vector: [Float] = [1, 0, 0, 0]
        let doc = document(
            title: "Helping coaches find people to work with",
            text: "Nothing here uses the query's words at all",
            embedding: vector
        )

        let hits = IdeaSearch.rank(query: "client acquisition", in: [doc], queryVector: vector)

        #expect(hits.count == 1)
        #expect(hits.first?.reason == .meaning)
        #expect(hits.first?.isLiteral == false)
    }

    /// The regression that would matter most: semantic scoring must not outrank an exact
    /// title hit just because the vectors happen to line up.
    @Test("Meaning never outranks an exact title match")
    func literalBeatsSemantic() {
        let vector: [Float] = [1, 0, 0, 0]
        let exact = document(title: "Meal prep", text: "Unrelated body", embedding: [0, 1, 0, 0])
        let similar = document(title: "Totally different", text: "Also different", embedding: vector)

        let hits = IdeaSearch.rank(query: "Meal prep", in: [similar, exact], queryVector: vector)

        #expect(hits.first?.id == exact.id)
        #expect(hits.first?.reason == .title)
    }

    @Test("Every word present in any order still matches")
    func allWordsInAnyOrder() {
        let doc = document(title: "Untitled", text: "An app for finding quiet coffee shops to work in")
        let hits = IdeaSearch.rank(query: "coffee shop app", in: [doc], queryVector: nil)

        // "shop" appears inside "shops", "coffee" and "app" both appear.
        #expect(hits.count == 1)
    }

    @Test("An empty query returns nothing rather than everything")
    func emptyQuery() {
        let doc = document(title: "Anything", text: "At all")

        #expect(IdeaSearch.rank(query: "", in: [doc], queryVector: nil).isEmpty)
        #expect(IdeaSearch.rank(query: "   ", in: [doc], queryVector: nil).isEmpty)
    }

    /// Search has to keep working on a device with no embedding model, and on ideas
    /// captured before enrichment ever ran.
    @Test("Search still works with no vectors at all")
    func worksWithoutEmbeddings() {
        let doc = document(title: "Client tracking app", text: "For trainers")
        let hits = IdeaSearch.rank(query: "trainers", in: [doc], queryVector: nil)

        #expect(hits.count == 1)
        #expect(hits.first?.reason == .body)
    }

    @Test("Results are ordered by score, best first")
    func ordering() {
        let strong = document(title: "Packaging", text: "x")
        let weak = document(title: "Unrelated", text: "a note that mentions packaging in passing")

        let hits = IdeaSearch.rank(query: "packaging", in: [weak, strong], queryVector: nil)

        #expect(hits.count == 2)
        #expect(hits[0].id == strong.id)
        #expect(hits[0].score > hits[1].score)
    }
}
