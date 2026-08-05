import CoreGraphics
import Foundation
import SwiftData
import Testing

@testable import Remli

/// Where the ideas end up on the map.
///
/// This is the part that kept shipping broken, and always in the same way: the layout's
/// spread was emergent, so the view tried to compensate with zoom limits that suited one
/// library and not another. Unconnected ideas repelled until they were thousands of points
/// apart and simply fell off the screen. Normalising the result to a known box is what
/// makes "show me everything" arithmetic instead of a guess, and these lock that down.
@Suite("Graph layout")
struct GraphLayoutTests {

    private func makeContext() throws -> ModelContext {
        let container = try RemliSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    /// `count` ideas with no links between them — the worst case for a force layout, and
    /// exactly what a new library looks like.
    private func unconnectedGraph(count: Int, context: ModelContext) -> IdeaGraph {
        var ideas: [Idea] = []
        for index in 0..<count {
            let idea = Idea(text: "Unconnected idea number \(index)")
            context.insert(idea)
            ideas.append(idea)
        }
        return IdeaGraph(ideas: ideas)
    }

    private let area = CGSize(width: 1000, height: 1000)

    @Test("Unconnected ideas stay inside the canvas instead of flying apart")
    func unconnectedIdeasAreBounded() throws {
        let context = try makeContext()
        let graph = unconnectedGraph(count: 4, context: context)

        let result = GraphLayout.compute(graph: graph, area: area)

        for (_, point) in result.positions {
            #expect(point.x >= -1 && point.x <= area.width + 1, "x escaped the canvas: \(point.x)")
            #expect(point.y >= -1 && point.y <= area.height + 1, "y escaped the canvas: \(point.y)")
        }
    }

    @Test("The layout fills the canvas rather than collapsing into a dot")
    func layoutUsesTheSpace() throws {
        let context = try makeContext()
        let graph = unconnectedGraph(count: 6, context: context)

        let result = GraphLayout.compute(graph: graph, area: area)
        let spread = max(result.bounds.width, result.bounds.height)

        // Normalisation targets the smaller dimension, and `bounds` adds padding, so the
        // spread lands near the canvas size rather than exactly on it.
        #expect(spread > area.width * 0.5, "layout collapsed: spread \(spread)")
        #expect(spread < area.width * 1.5, "layout overflowed: spread \(spread)")
    }

    /// Two ideas and twenty should both be fully visible at the same zoom, which is only
    /// true if the normalisation is independent of node count.
    @Test("Spread is stable across library sizes")
    func spreadIsStableAcrossSizes() throws {
        let context = try makeContext()

        var spreads: [CGFloat] = []
        for count in [2, 5, 20] {
            let graph = unconnectedGraph(count: count, context: context)
            let result = GraphLayout.compute(graph: graph, area: area)
            spreads.append(max(result.bounds.width, result.bounds.height))
        }

        let smallest = try #require(spreads.min())
        let largest = try #require(spreads.max())
        #expect(largest / smallest < 2, "spread varies too much with node count: \(spreads)")
    }

    @Test("A single idea sits in the middle")
    func singleIdeaIsCentred() throws {
        let context = try makeContext()
        let graph = unconnectedGraph(count: 1, context: context)

        let result = GraphLayout.compute(graph: graph, area: area)
        let point = try #require(result.positions.values.first)

        #expect(abs(point.x - area.width / 2) < 1)
        #expect(abs(point.y - area.height / 2) < 1)
    }

    @Test("An empty graph produces nothing rather than crashing")
    func emptyGraph() {
        let result = GraphLayout.compute(graph: IdeaGraph(), area: area)
        #expect(result.positions.isEmpty)
    }

    /// The map is a place you learn, not a fresh scramble each visit.
    @Test("The same ideas lay out identically every time")
    func layoutIsDeterministic() throws {
        let context = try makeContext()
        let graph = unconnectedGraph(count: 5, context: context)

        let first = GraphLayout.compute(graph: graph, area: area)
        let second = GraphLayout.compute(graph: graph, area: area)

        for (id, point) in first.positions {
            let other = try #require(second.positions[id])
            #expect(abs(point.x - other.x) < 0.001)
            #expect(abs(point.y - other.y) < 0.001)
        }
    }

    @Test("Connected ideas end up closer together than unconnected ones")
    func linksPullIdeasTogether() throws {
        let context = try makeContext()

        let a = Idea(text: "Meal prep subscription service")
        let b = Idea(text: "Weekly delivery route planning")
        let c = Idea(text: "Learning to play the piano")
        for idea in [a, b, c] { context.insert(idea) }

        context.insert(
            IdeaLink(source: a, target: b, kind: .relatesTo, rationale: "Same business", strength: 0.9)
        )

        let result = GraphLayout.compute(graph: IdeaGraph(ideas: [a, b, c]), area: area)

        let pa = try #require(result.positions[a.id])
        let pb = try #require(result.positions[b.id])
        let pc = try #require(result.positions[c.id])

        let linked = hypot(pa.x - pb.x, pa.y - pb.y)
        let unlinked = hypot(pa.x - pc.x, pa.y - pc.y)

        #expect(linked < unlinked, "linked \(linked) should be closer than unlinked \(unlinked)")
    }
}
