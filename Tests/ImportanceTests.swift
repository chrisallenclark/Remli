import Foundation
import SwiftData
import Testing

@testable import Remli

/// The importance score, and the rule that a correction has to actually count.
///
/// The failure these guard against is not a crash — it is a placebo: a control that looks
/// like it does something, writes a value nobody reads, and quietly teaches the person
/// that their input does not matter.
@Suite("Importance")
struct ImportanceTests {

    private func makeContext() throws -> ModelContext {
        let container = try RemliSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    @Test("An un-corrected idea reports the model's guess")
    func fallsBackToTheGuess() {
        let idea = Idea(text: "Client tracking app")
        idea.importanceScore = 0.72
        #expect(idea.importance == 0.72)
        #expect(idea.importanceIsUserSet == false)
    }

    @Test("A correction wins, and the guess survives underneath it")
    func overrideWinsWithoutErasing() {
        let idea = Idea(text: "Client tracking app")
        idea.importanceScore = 0.72

        idea.setImportance(.passing)

        #expect(idea.importance == ImportanceLevel.passing.score)
        #expect(idea.importanceIsUserSet)
        // The whole point of two fields: you can still see what it assumed.
        #expect(idea.importanceScore == 0.72)
        #expect(idea.importanceGuessLevel == .matters)
    }

    @Test("Re-enrichment cannot undo a correction")
    func enrichmentDoesNotOverrideYou() {
        let idea = Idea(text: "Client tracking app")
        idea.importanceScore = 0.72
        idea.setImportance(.major)

        // Exactly what EnrichmentService does on a later pass.
        idea.importanceScore = 0.20

        #expect(idea.importance == ImportanceLevel.major.score)
    }

    @Test("Clearing a correction returns to the guess")
    func revertingRestoresTheGuess() {
        let idea = Idea(text: "Client tracking app")
        idea.importanceScore = 0.72
        idea.setImportance(.passing)
        idea.setImportance(nil)

        #expect(idea.importance == 0.72)
        #expect(idea.importanceIsUserSet == false)
    }

    @Test("Every level round-trips to itself")
    func levelsRoundTrip() {
        for level in ImportanceLevel.allCases {
            #expect(ImportanceLevel.nearest(to: level.score) == level)
        }
    }

    @Test("Scores between levels land on the nearer one")
    func nearestPicksTheCloserLevel() {
        #expect(ImportanceLevel.nearest(to: 0.0) == .passing)
        #expect(ImportanceLevel.nearest(to: 1.0) == .major)
        #expect(ImportanceLevel.nearest(to: 0.70) == .matters)
        #expect(ImportanceLevel.nearest(to: 0.44) == .worthKeeping)
    }

    @Test("Resurfacing reads the correction, not the guess")
    func resurfacingObeysYou() {
        let idea = Idea(text: "Client tracking app")
        idea.importanceScore = 0.05
        idea.setImportance(.major)

        let candidate = ResurfacingCandidate(idea)
        #expect(candidate.importance == ImportanceLevel.major.score)
    }

    @Test("The map reads the correction, not the guess")
    func theMapObeysYou() throws {
        let context = try makeContext()
        let quiet = Idea(text: "A thought the model shrugged at")
        let loud = Idea(text: "Another thought entirely")
        quiet.importanceScore = 0.05
        loud.importanceScore = 0.05
        quiet.isEnriched = true
        loud.isEnriched = true
        context.insert(quiet)
        context.insert(loud)

        quiet.setImportance(.major)

        let graph = IdeaGraph(ideas: [quiet, loud])
        let quietNode = try #require(graph.node(quiet.id))
        let loudNode = try #require(graph.node(loud.id))

        #expect(quietNode.importance == ImportanceLevel.major.score)
        // Neither is connected, so importance is the only thing separating them — which
        // is exactly the case where a correction has to show.
        #expect(graph.anchor(quietNode) > graph.anchor(loudNode))
    }
}

/// Node sizing: the three inputs, and what happens when one of them is missing.
@Suite("Map node weighting")
struct MapWeightingTests {

    private func makeContext() throws -> ModelContext {
        let container = try RemliSchema.makeContainer(inMemory: true)
        return ModelContext(container)
    }

    private func link(
        _ from: Idea,
        _ to: Idea,
        strength: Double,
        in context: ModelContext
    ) {
        let link = IdeaLink(
            source: from,
            target: to,
            kind: .relatesTo,
            rationale: "Because.",
            strength: strength
        )
        // Inserting is enough: the inverse relationship populates `outgoingLinks`, which is
        // what `IdeaGraph` reads. Appending by hand as well would put the link in twice.
        context.insert(link)
    }

    @Test("Connections count in both directions")
    func degreeIsUndirected() throws {
        let context = try makeContext()
        let hub = Idea(text: "Hub")
        let a = Idea(text: "A")
        let b = Idea(text: "B")
        for idea in [hub, a, b] {
            idea.isEnriched = true
            context.insert(idea)
        }
        link(a, hub, strength: 0.6, in: context)
        link(hub, b, strength: 0.6, in: context)

        let graph = IdeaGraph(ideas: [hub, a, b])
        #expect(try #require(graph.node(hub.id)).connections == 2)
        #expect(try #require(graph.node(a.id)).connections == 1)
        #expect(graph.maxConnections == 2)
    }

    @Test("A declared goal is substantial before anything links to it")
    func goalsAreNotDust() throws {
        let context = try makeContext()
        let goal = Idea(text: "The thing I am building")
        let stray = Idea(text: "A passing thought")
        for idea in [goal, stray] {
            idea.isEnriched = true
            idea.importanceScore = 0.3
            context.insert(idea)
        }
        goal.isGoal = true

        let graph = IdeaGraph(ideas: [goal, stray])
        let goalNode = try #require(graph.node(goal.id))
        let strayNode = try #require(graph.node(stray.id))

        #expect(graph.anchor(goalNode) > graph.anchor(strayNode))
        #expect(MapMetrics.idleRadius(goalNode, in: graph) > MapMetrics.idleRadius(strayNode, in: graph))
    }

    @Test("Anchor stays inside 0…1 at both extremes")
    func anchorIsBounded() throws {
        let context = try makeContext()
        let everything = Idea(text: "Maximal")
        let other = Idea(text: "Other")
        for idea in [everything, other] {
            idea.isEnriched = true
            context.insert(idea)
        }
        everything.isGoal = true
        everything.importanceScore = 1
        link(everything, other, strength: 1, in: context)

        let graph = IdeaGraph(ideas: [everything, other])
        for node in graph.nodes {
            let anchor = graph.anchor(node)
            #expect(anchor >= 0 && anchor <= 1)
        }
    }

    @Test("Focus sizing ranks by relatedness, not by global standing")
    func focusSizesByStrength() throws {
        let context = try makeContext()
        let hub = Idea(text: "Hub")
        // Deliberately the *less* important idea, tied tightly to the hub.
        let close = Idea(text: "Closely related")
        // More important on its own, barely related to the hub.
        let distant = Idea(text: "Loosely related")
        for idea in [hub, close, distant] {
            idea.isEnriched = true
            context.insert(idea)
        }
        close.importanceScore = 0.2
        distant.importanceScore = 0.9

        link(hub, close, strength: 0.95, in: context)
        link(hub, distant, strength: 0.15, in: context)

        let graph = IdeaGraph(ideas: [hub, close, distant])
        let neighbours = graph.neighbours(of: hub.id)

        let closeRadius = MapMetrics.focusRadius(
            try #require(graph.node(close.id)),
            hub: hub.id, neighbours: neighbours, in: graph
        )
        let distantRadius = MapMetrics.focusRadius(
            try #require(graph.node(distant.id)),
            hub: hub.id, neighbours: neighbours, in: graph
        )

        #expect(closeRadius > distantRadius)
    }

    @Test("An idea unrelated to the hub shrinks rather than vanishing")
    func unrelatedShrinks() throws {
        let context = try makeContext()
        let hub = Idea(text: "Hub")
        let unrelated = Idea(text: "Nothing to do with it")
        for idea in [hub, unrelated] {
            idea.isEnriched = true
            context.insert(idea)
        }

        let graph = IdeaGraph(ideas: [hub, unrelated])
        let node = try #require(graph.node(unrelated.id))
        let idle = MapMetrics.idleRadius(node, in: graph)
        let focused = MapMetrics.focusRadius(
            node, hub: hub.id, neighbours: [], in: graph
        )

        #expect(focused < idle)
        #expect(focused > 0)
    }

    @Test("Brightness falls off with neglect and never reaches zero")
    func heatFades() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func node(daysAgo: Double) -> GraphNode {
            GraphNode(
                id: UUID(),
                title: "x",
                colorHex: nil,
                status: .seed,
                importance: 0.5,
                updatedAt: now.addingTimeInterval(-daysAgo * 86_400),
                connections: 0,
                isGoal: false
            )
        }

        #expect(MapMetrics.heat(node(daysAgo: 0), now: now) == 1)
        #expect(MapMetrics.heat(node(daysAgo: 7), now: now) == 1)
        #expect(MapMetrics.heat(node(daysAgo: 40), now: now) < 1)
        #expect(MapMetrics.heat(node(daysAgo: 40), now: now) > MapMetrics.heat(node(daysAgo: 80), now: now))
        #expect(MapMetrics.heat(node(daysAgo: 5_000), now: now) >= 0.18)

        #expect(MapMetrics.isCold(node(daysAgo: 29), now: now) == false)
        #expect(MapMetrics.isCold(node(daysAgo: 31), now: now))
    }

    @Test("Labels wrap inside a disc without dropping words")
    func labelsWrap() {
        let lines = MapMetrics.wrap(
            "Personal Operating System",
            maxWidth: 78,
            fontSize: 11,
            maxLines: 3
        )
        #expect(lines.count >= 2)
        #expect(lines.count <= 3)
        #expect(lines.joined(separator: " ").hasPrefix("Personal"))

        let single = MapMetrics.wrap("Remli", maxWidth: 78, fontSize: 11, maxLines: 3)
        #expect(single == ["Remli"])

        // Everything that will not fit collapses onto the last line and is elided, rather
        // than words silently disappearing off the end.
        let squeezed = MapMetrics.wrap(
            "Lead Follow-Up Automation For Trainers",
            maxWidth: 40,
            fontSize: 11,
            maxLines: 2
        )
        #expect(squeezed.count <= 2)
        #expect(squeezed.last?.hasSuffix("…") == true)
    }
}
