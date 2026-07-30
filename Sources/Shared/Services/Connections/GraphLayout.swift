import CoreGraphics
import Foundation

/// Force-directed layout — connected ideas pull together, everything pushes apart.
///
/// Deliberately deterministic. Seeding from a hash of each node's identifier rather than a
/// random number means the map looks the same every time you open it, so it becomes a
/// place you can learn rather than a fresh scramble on each visit.
enum GraphLayout {

    struct Result: Sendable {
        var positions: [UUID: CGPoint]
        var bounds: CGRect
    }

    /// Runs off the main actor — a few hundred nodes over a hundred iterations is real
    /// work, and it must not stutter a scroll.
    static func compute(
        graph: IdeaGraph,
        iterations: Int = 220,
        area: CGSize = CGSize(width: 1000, height: 1000)
    ) -> Result {
        let ids = graph.nodes.map(\.id)
        guard !ids.isEmpty else {
            return Result(positions: [:], bounds: .zero)
        }

        guard ids.count > 1 else {
            return Result(
                positions: [ids[0]: CGPoint(x: area.width / 2, y: area.height / 2)],
                bounds: CGRect(origin: .zero, size: area)
            )
        }

        var positions = seedPositions(for: ids, in: area)

        // Fruchterman–Reingold. `k` is the natural spring length: the spacing at which
        // repulsion and attraction balance for the given node count and canvas area.
        let k = sqrt((area.width * area.height) / CGFloat(ids.count))
        var temperature = area.width / 8

        // Adjacency as index pairs, resolved once rather than per iteration.
        let indexOf = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        let springs: [(Int, Int, CGFloat)] = graph.edges.compactMap { edge in
            guard
                let a = indexOf[edge.source],
                let b = indexOf[edge.target],
                a != b
            else { return nil }
            // Stronger links pull harder, so confident clusters draw themselves tighter.
            return (a, b, CGFloat(0.5 + edge.strength))
        }

        var points = ids.map { positions[$0] ?? .zero }

        for _ in 0..<iterations {
            var displacement = [CGPoint](repeating: .zero, count: points.count)

            // Repulsion, every pair. O(n²) is fine at this scale and avoids the
            // complexity of a Barnes–Hut tree for a few hundred nodes.
            for i in 0..<points.count {
                for j in (i + 1)..<points.count {
                    var delta = CGPoint(
                        x: points[i].x - points[j].x,
                        y: points[i].y - points[j].y
                    )
                    var distance = hypot(delta.x, delta.y)

                    // Coincident nodes have no direction to separate along, so nudge them
                    // apart deterministically using their index.
                    if distance < 0.01 {
                        delta = CGPoint(x: CGFloat(i % 7) + 0.5, y: CGFloat(j % 5) + 0.5)
                        distance = hypot(delta.x, delta.y)
                    }

                    let force = (k * k) / distance
                    let push = CGPoint(x: delta.x / distance * force, y: delta.y / distance * force)

                    displacement[i].x += push.x
                    displacement[i].y += push.y
                    displacement[j].x -= push.x
                    displacement[j].y -= push.y
                }
            }

            // Attraction along edges.
            for (a, b, weight) in springs {
                let delta = CGPoint(x: points[a].x - points[b].x, y: points[a].y - points[b].y)
                let distance = max(hypot(delta.x, delta.y), 0.01)
                let force = (distance * distance) / k * weight
                let pull = CGPoint(x: delta.x / distance * force, y: delta.y / distance * force)

                displacement[a].x -= pull.x
                displacement[a].y -= pull.y
                displacement[b].x += pull.x
                displacement[b].y += pull.y
            }

            for index in points.indices {
                let move = displacement[index]
                let magnitude = max(hypot(move.x, move.y), 0.01)
                // Temperature caps how far anything can travel in one step, which is what
                // stops the early iterations from flinging nodes off the canvas.
                let limited = min(magnitude, temperature)
                points[index].x += move.x / magnitude * limited
                points[index].y += move.y / magnitude * limited
            }

            temperature = max(temperature * 0.95, 0.5)
        }

        for (index, id) in ids.enumerated() {
            positions[id] = points[index]
        }

        return Result(positions: positions, bounds: bounds(of: points))
    }

    /// A ring, ordered by a hash of the identifier. Stable across launches, and a circle
    /// starts every node roughly equidistant, which converges faster than a random cloud.
    private static func seedPositions(for ids: [UUID], in area: CGSize) -> [UUID: CGPoint] {
        let centre = CGPoint(x: area.width / 2, y: area.height / 2)
        let radius = min(area.width, area.height) / 3

        var result: [UUID: CGPoint] = [:]
        for (index, id) in ids.enumerated() {
            let angle = (CGFloat(index) / CGFloat(ids.count)) * 2 * .pi
            // A small per-node offset breaks the perfect symmetry that would otherwise
            // leave the forces balanced and the layout frozen.
            let jitter = CGFloat(abs(id.hashValue) % 100) / 100 * 20
            result[id] = CGPoint(
                x: centre.x + cos(angle) * (radius + jitter),
                y: centre.y + sin(angle) * (radius + jitter)
            )
        }
        return result
    }

    private static func bounds(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }

        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        let padding: CGFloat = 60
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: max(maxX - minX + padding * 2, 1),
            height: max(maxY - minY + padding * 2, 1)
        )
    }
}
