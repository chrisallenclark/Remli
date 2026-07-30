import Foundation

/// The filter chips above the ideas list.
///
/// Categories are emergent, so the collection set has to be computed from what is actually
/// there rather than hard-coded. The fixed ones earn their place by answering questions a
/// category never can: *what could I finish quickly*, and *what did I start and abandon*.
enum SmartCollection: Identifiable, Equatable, Hashable {
    case all
    case quickWins
    case inProgress
    case tasks
    case category(id: UUID, name: String)

    var id: String {
        switch self {
        case .all: return "all"
        case .quickWins: return "quick"
        case .inProgress: return "progress"
        case .tasks: return "tasks"
        case .category(let id, _): return "cat.\(id.uuidString)"
        }
    }

    var label: String {
        switch self {
        case .all: return "All"
        case .quickWins: return "Quick wins"
        case .inProgress: return "In progress"
        case .tasks: return "To-dos"
        case .category(_, let name): return name
        }
    }

    var symbolName: String {
        switch self {
        case .all: return "square.stack"
        case .quickWins: return "bolt"
        case .inProgress: return "circle.lefthalf.filled"
        case .tasks: return "checkmark.circle"
        case .category: return "folder"
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
        case .category(let id, _):
            return idea.category?.id == id
        }
    }

    /// Builds the visible set. A collection that would be empty is never offered — a chip
    /// that leads to nothing is just a dead end.
    static func available(for ideas: [Idea]) -> [SmartCollection] {
        var result: [SmartCollection] = [.all]

        for candidate in [SmartCollection.inProgress, .quickWins, .tasks] {
            if ideas.contains(where: { candidate.matches($0) }) {
                result.append(candidate)
            }
        }

        // Categories ordered by how much is in them, so the ones actually being used sit
        // where they can be reached.
        var counts: [UUID: (name: String, count: Int)] = [:]
        for idea in ideas {
            guard let category = idea.category else { continue }
            counts[category.id, default: (category.name, 0)].count += 1
        }

        let sorted = counts
            .map { (id: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { lhs, rhs in
                lhs.count == rhs.count ? lhs.name < rhs.name : lhs.count > rhs.count
            }

        for entry in sorted {
            result.append(.category(id: entry.id, name: entry.name))
        }

        return result
    }
}
