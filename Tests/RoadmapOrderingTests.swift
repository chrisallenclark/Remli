import Foundation
import SwiftData
import Testing

@testable import Remli

/// What may and may not claim that one idea comes before another.
///
/// These exist because the first version got it wrong in a way that was confidently
/// wrong rather than obviously wrong: a client-tracking app for trainers, an operating
/// system for entrepreneurs and Remli itself were strung into a single sequence, because
/// `buildsOn` — which means "elaborates on the same theme" — was being read as "must
/// happen first". Family resemblance is not a plan.
@Suite("Roadmap ordering")
struct RoadmapOrderingTests {

    private func makeContext() throws -> ModelContext {
        let container = try RemliSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    /// Builds two ideas joined by one link, and returns the graph over them.
    private func graph(
        kind: LinkKind,
        strength: Double,
        rationale: String = "Because.",
        context: ModelContext
    ) -> (graph: IdeaGraph, first: Idea, second: Idea) {
        let first = Idea(text: "Client tracking app for personal trainers")
        let second = Idea(text: "A personal operating system for entrepreneurs")
        first.isEnriched = true
        second.isEnriched = true
        context.insert(first)
        context.insert(second)

        let link = IdeaLink(
            source: first,
            target: second,
            kind: kind,
            rationale: rationale,
            strength: strength
        )
        context.insert(link)

        return (IdeaGraph(ideas: [first, second]), first, second)
    }

    @Test("A confident prerequisite creates a roadmap step")
    func strongPrerequisiteOrders() throws {
        let context = try makeContext()
        let built = graph(kind: .prerequisiteFor, strength: 0.8, context: context)

        let chains = built.graph.chains()
        #expect(chains.count == 1)
        #expect(chains.first == [built.first.id, built.second.id])
    }

    /// The regression that prompted all of this.
    @Test("Builds-on never claims an order")
    func buildsOnDoesNotOrder() throws {
        let context = try makeContext()
        let built = graph(kind: .buildsOn, strength: 0.95, context: context)

        #expect(built.graph.chains().isEmpty)
        // It still belongs on the map — elaboration is a real relationship, just not a step.
        #expect(built.graph.edges.count == 1)
    }

    @Test("Merely related ideas never claim an order")
    func softKindsDoNotOrder() throws {
        let context = try makeContext()

        for kind in [LinkKind.relatesTo, .variantOf, .contradicts] {
            let built = graph(kind: kind, strength: 0.99, context: context)
            #expect(built.graph.chains().isEmpty, "\(kind) should not create a roadmap step")
        }
    }

    @Test("A weak prerequisite is not confident enough to be a step")
    func weakPrerequisiteIsIgnored() throws {
        let context = try makeContext()
        let built = graph(kind: .prerequisiteFor, strength: 0.3, context: context)

        #expect(built.graph.chains().isEmpty)
    }

    @Test("Every step can explain itself")
    func stepsCarryTheirReasoning() throws {
        let context = try makeContext()
        let built = graph(
            kind: .prerequisiteFor,
            strength: 0.8,
            rationale: "The tracking app proves the billing flow the OS depends on.",
            context: context
        )

        let edge = built.graph.orderingEdge(from: built.first.id, to: built.second.id)
        #expect(edge?.rationale == "The tracking app proves the billing flow the OS depends on.")

        // And the reverse direction is not a step — order is a directed claim.
        #expect(built.graph.orderingEdge(from: built.second.id, to: built.first.id) == nil)
    }

    /// The model will occasionally emit A→B and B→A. Traversal must terminate rather than
    /// recurse until the stack gives out, because this runs while someone is looking at it.
    @Test("A cycle does not hang the traversal")
    func cyclesTerminate() throws {
        let context = try makeContext()

        let a = Idea(text: "Idea A")
        let b = Idea(text: "Idea B")
        context.insert(a)
        context.insert(b)

        context.insert(IdeaLink(source: a, target: b, kind: .prerequisiteFor, rationale: "x", strength: 0.9))
        context.insert(IdeaLink(source: b, target: a, kind: .prerequisiteFor, rationale: "y", strength: 0.9))

        let chains = IdeaGraph(ideas: [a, b]).chains()
        for chain in chains {
            #expect(chain.count == Set(chain).count, "a chain must not repeat an idea")
        }
    }

    @Test("To-dos stay out of the graph entirely")
    func tasksAreExcluded() throws {
        let context = try makeContext()

        let idea = Idea(text: "A real idea")
        let chore = Idea(text: "Call the dentist")
        chore.kind = .task
        context.insert(idea)
        context.insert(chore)

        let built = IdeaGraph(ideas: [idea, chore])
        #expect(built.nodes.count == 1)
        #expect(built.nodes.first?.id == idea.id)
    }
}
