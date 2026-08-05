import Foundation

/// The filter chips above the ideas list.
///
/// A *saved view*, not a container — this is what "Collection" must never be confused with.
/// A `SmartCollection` is computed on every render and stores nothing; a Collection is a
/// row in the database that ideas belong to. The chips happen to show both, because you
/// filter by them the same way.
///
/// Spaces are emergent, so the chip set is computed from what is actually there rather
/// than hard-coded. The fixed ones earn their place by answering questions a Space never
/// can: *what could I finish quickly*, and *what did I start and abandon*.
enum SmartCollection: Identifiable, Equatable, Hashable {
    case all
    case quickWins
    case inProgress
    case tasks
    case category(id: UUID, name: String, isCollection: Bool)

    var id: String {
        switch self {
        case .all: return "all"
        case .quickWins: return "quick"
        case .inProgress: return "progress"
        case .tasks: return "tasks"
        case .category(let id, _, _): return "cat.\(id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .all: return "All"
        case .quickWins: return "Quick wins"
        case .inProgress: return "In progress"
        case .tasks: return "To-dos"
        case .category(_, let name, _): return name
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.stack"
        case .quickWins: return "bolt"
        case .inProgress: return "circle.lefthalf.filled"
        case .tasks: return "checkmark.circle"
        // A Collection chip sits immediately after its Space's, so the distinct glyph is
        // what stops "Business, Meal Prep, Bartending, Health" reading as four peers.
        case .category(_, _, let isCollection):
            return isCollection ? "arrow.turn.down.right" : "square.stack.3d.up"
        }
    }

    /// Anything achievable in a sitting. Matched against the model's effort estimate, which
    /// is exactly what the free-time notifications use, so the two agree.
    static let quickWinMinutes = 30

    func matches(_ idea: Idea) -> Bool {
        switch self {
        case .all:
            return true
        case .quickWins:
            return idea.kind == .idea
                && idea.status != .done
                && idea.estimatedMinutes > 0
                && idea.estimatedMinutes <= Self.quickWinMinutes
        case .inProgress:
            return idea.status == .active
        case .tasks:
            return idea.kind == .task && idea.status != .done
        case .category(let id, _, let isCollection):
            guard let category = idea.category else { return false }
            if category.id == id { return true }
            // A Space shows everything underneath it. Selecting "Business" and being shown
            // nothing, because all three ideas now live in Collections, would punish you
            // for organising. Nesting is capped at one level, so one hop up is the whole
            // hierarchy.
            return isCollection ? false : category.parent?.id == id
        }
    }

    /// Builds the visible set. A chip that would be empty is never offered — one that leads
    /// to nothing is just a dead end.
    static func available(for ideas: [Idea]) -> [SmartCollection] {
        var result: [SmartCollection] = [.all]

        for candidate in [SmartCollection.inProgress, .quickWins, .tasks] {
            if ideas.contains(where: { candidate.matches($0) }) {
                result.append(candidate)
            }
        }

        // Spaces ordered by how much is in them, so the ones actually being used sit where
        // they can be reached, with each Space's Collections directly after it.
        //
        // A named struct rather than a labelled tuple: chaining map/sorted over an
        // anonymous tuple is reliably enough to time out the expression type checker.
        struct Tally {
            var id: UUID
            var name: String
            var parentID: UUID?
            /// Includes Collections, which is what orders a Space correctly once its ideas
            /// have all been moved down a level.
            var total: Int
        }

        var counts: [UUID: Tally] = [:]

        for idea in ideas {
            guard let category = idea.category else { continue }

            if counts[category.id] == nil {
                counts[category.id] = Tally(
                    id: category.id,
                    name: category.name,
                    parentID: category.parent?.id,
                    total: 0
                )
            }
            counts[category.id]?.total += 1

            // A Space whose ideas all live in its Collections still deserves a chip, so it
            // is registered here even though no idea points at it directly.
            if let parent = category.parent {
                if counts[parent.id] == nil {
                    counts[parent.id] = Tally(
                        id: parent.id,
                        name: parent.name,
                        parentID: nil,
                        total: 0
                    )
                }
                counts[parent.id]?.total += 1
            }
        }

        func ordered(_ tallies: [Tally]) -> [Tally] {
            var copy = tallies
            copy.sort { lhs, rhs in
                if lhs.total == rhs.total {
                    return lhs.name < rhs.name
                }
                return lhs.total > rhs.total
            }
            return copy
        }

        var roots: [Tally] = []
        for tally in counts.values where tally.parentID == nil {
            roots.append(tally)
        }

        for root in ordered(roots) {
            result.append(.category(id: root.id, name: root.name, isCollection: false))

            var children: [Tally] = []
            for tally in counts.values where tally.parentID == root.id {
                children.append(tally)
            }
            for child in ordered(children) {
                result.append(.category(id: child.id, name: child.name, isCollection: true))
            }
        }

        return result
    }
}
