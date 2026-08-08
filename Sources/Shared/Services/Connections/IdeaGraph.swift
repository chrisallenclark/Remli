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
    /// 0–1. The person's own figure where they have given one, the model's otherwise.
    let importance: Double
    /// When the idea was last touched. Drives how brightly the node burns, which is how
    /// neglect becomes something you can see rather than something you have to remember.
    let updatedAt: Date
    /// How many active links touch it, in either direction.
    let connections: Int
    /// Whether it has been declared something you are actually building.
    let isGoal: Bool
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

    /// The most connections any single idea has, and never less than 1.
    ///
    /// Node size is measured against this rather than an absolute ceiling, so a library of
    /// nine ideas still has a proper biggest node instead of nine identical small ones, and
    /// the picture rescales as the library grows rather than slowly filling up.
    var maxConnections: Int = 1

    var isEmpty: Bool { nodes.isEmpty }

    func node(_ id: UUID) -> GraphNode? {
        nodes.first { $0.id == id }
    }

    // MARK: - Weighting

    /// How much an idea anchors: 0 for a stray thought, 1 for the thing everything hangs off.
    ///
    /// Three inputs, because any one of them alone is wrong. Connections alone make a
    /// well-connected throwaway the centre of the map. Importance alone ignores that your
    /// thinking keeps circling back to something. And a goal you have explicitly declared
    /// should read as substantial from the day you declare it, before anything links to it
    /// at all — that last term is what stops a brand-new commitment looking like dust.
    func anchor(_ node: GraphNode) -> Double {
        let reach = Double(node.connections) / Double(max(maxConnections, 1))
        let weighted = 0.45 * reach
            + 0.40 * min(max(node.importance, 0), 1)
            + 0.15 * (node.isGoal ? 1 : 0)
        return min(max(weighted, 0), 1)
    }

    /// How strongly two ideas are tied, in either direction. Zero when they are not.
    func strength(between a: UUID, and b: UUID) -> Double {
        edges.first { edge in
            (edge.source == a && edge.target == b) || (edge.source == b && edge.target == a)
        }?.strength ?? 0
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

        // Edges are gathered first so that nodes can be built already knowing how connected
        // each one is. Counting afterwards would mean either a second pass or a mutable
        // node, and the count is needed before the first thing is drawn.
        var seenEdges = Set<String>()
        var collected: [GraphEdge] = []
        var degree: [UUID: Int] = [:]

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

                degree[sourceID, default: 0] += 1
                degree[targetID, default: 0] += 1
            }
        }

        self.edges = collected
        self.maxConnections = max(degree.values.max() ?? 0, 1)

        self.nodes = included.map { idea in
            GraphNode(
                id: idea.id,
                title: idea.displayTitle,
                colorHex: idea.category?.colorHex,
                status: idea.status,
                // The person's correction where they have made one. This is the line that
                // makes disagreeing with the importance score change what you see.
                importance: idea.importance,
                updatedAt: idea.updatedAt,
                connections: degree[idea.id] ?? 0,
                isGoal: idea.isGoal
            )
        }
    }
}
