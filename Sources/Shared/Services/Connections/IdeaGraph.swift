import CoreGraphics
import Foundation

/// A snapshot of the idea graph, detached from SwiftData.
///
/// Pure values, so layout and path finding can run off the main actor and be tested
/// without a model container.
struct GraphNode: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let colorHex: String?
    let status: IdeaStatus
    /// 0–1. Drives node size, so what matters reads as bigger.
    let importance: Double
}

struct GraphEdge: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: UUID
    let target: UUID
    let kind: LinkKind
    let strength: Double
    let rationale: String
}

struct IdeaGraph: Equatable, Sendable {

    var nodes: [GraphNode] = []
    var edges: [GraphEdge] = []

    var isEmpty: Bool { nodes.isEmpty }

    func node(_ id: UUID) -> GraphNode? {
        nodes.first { $0.id == id }
    }

    // MARK: - Dependency ordering

    /// A roadmap step is a strong claim, so the bar is higher than for merely drawing a
    /// line on the map. Saying "finish A and B becomes possible" when the two are only
    /// loosely related is worse than saying nothing: it invents a plan the person never
    /// made and then asks them to follow it.
    static let minimumOrderStrength = 0.55

    /// Ideas in dependency order.
    ///
    /// **Only `prerequisiteFor` counts.** `buildsOn` used to be folded in here as its
    /// reverse, which is where spurious roadmaps came from: "builds on" means one idea
    /// elaborates another — a personal-operating-system idea and an app that shares its
    /// spirit — and that is a family resemblance, not a sequence. Reading it as order
    /// produced confident nonsense like *finish the OS, then Remli becomes possible*.
    /// Elaboration still shows on the map, where it belongs; it just no longer claims
    /// anything about what to do first.
    private var precedence: [(before: UUID, after: UUID)] {
        edges.compactMap { edge in
            guard edge.kind == .prerequisiteFor else { return nil }
            guard edge.strength >= Self.minimumOrderStrength else { return nil }
            return (edge.source, edge.target)
        }
    }

    /// The link that put these two in sequence, so the roadmap can show its reasoning
    /// rather than asserting an order the reader has to take on faith.
    func orderingEdge(from before: UUID, to after: UUID) -> GraphEdge? {
        edges.first { edge in
            edge.kind == .prerequisiteFor
                && edge.strength >= Self.minimumOrderStrength
                && edge.source == before
                && edge.target == after
        }
    }

    /// Maximal dependency chains — the routes through your ideas where finishing one
    /// genuinely opens up the next.
    ///
    /// The model can and will occasionally emit a cycle (A unlocks B, B unlocks A), so
    /// traversal carries the current path and refuses to revisit it. Depth and breadth are
    /// capped because the number of simple paths in a dense graph is exponential and this
    /// runs while somebody is looking at a screen.
    func chains(maxDepth: Int = 8, maxChains: Int = 40) -> [[UUID]] {
        let links = precedence
        guard !links.isEmpty else { return [] }

        var successors: [UUID: [UUID]] = [:]
        var hasIncoming: Set<UUID> = []

        for link in links {
            successors[link.before, default: []].append(link.after)
            hasIncoming.insert(link.after)
        }

        // Start only from nodes nothing depends on — the true beginnings of a thread.
        // A pure cycle has no such node, which is why the fallback below exists.
        var roots = successors.keys.filter { !hasIncoming.contains($0) }
        if roots.isEmpty { roots = Array(successors.keys) }

        var chains: [[UUID]] = []

        func walk(_ current: UUID, path: [UUID]) {
            guard chains.count < maxChains else { return }

            let next = (successors[current] ?? []).filter { !path.contains($0) }

            if next.isEmpty || path.count >= maxDepth {
                if path.count >= 2 { chains.append(path) }
                return
            }

            for successor in next {
                walk(successor, path: path + [successor])
            }
        }

        for root in roots.sorted(by: { $0.uuidString < $1.uuidString }) {
            walk(root, path: [root])
        }

        // Longest first — the deepest chain is the most interesting thing on the screen.
        return chains.sorted { $0.count > $1.count }
    }

    /// Undirected neighbours, for highlighting when a node is selected.
    func neighbours(of id: UUID) -> Set<UUID> {
        var result = Set<UUID>()
        for edge in edges {
            if edge.source == id { result.insert(edge.target) }
            if edge.target == id { result.insert(edge.source) }
        }
        return result
    }
}

// MARK: - Building from the store

extension IdeaGraph {

    /// Builds a graph from ideas and their links.
    ///
    /// Tasks are excluded — they are never linked, and including them would scatter
    /// disconnected dots across the map for no benefit.
    init(ideas: [Idea]) {
        let included = ideas.filter { $0.kind == .idea }
        let includedIDs = Set(included.map(\.id))

        self.nodes = included.map { idea in
            GraphNode(
                id: idea.id,
                title: idea.displayTitle,
                colorHex: idea.category?.colorHex,
                status: idea.status,
                importance: idea.importanceScore
            )
        }

        var seenEdges = Set<String>()
        var collected: [GraphEdge] = []

        for idea in included {
            for link in idea.outgoingLinks ?? [] {
                guard
                    // Pending and rejected links are not part of the picture. A proposal
                    // drawn on the map would be indistinguishable from a fact.
                    link.isActive,
                    let sourceID = link.source?.id,
                    let targetID = link.target?.id,
                    includedIDs.contains(sourceID),
                    includedIDs.contains(targetID),
                    seenEdges.insert(link.dedupeKey).inserted
                else { continue }

                collected.append(
                    GraphEdge(
                        id: link.id,
                        source: sourceID,
                        target: targetID,
                        kind: link.kind,
                        strength: link.strength,
                        rationale: link.rationale
                    )
                )
            }
        }

        self.edges = collected
    }
}
