import Foundation

/// Enumerations are persisted as raw strings rather than as Swift enums directly.
///
/// SwiftData can store enums, but raw strings survive schema evolution far better: adding
/// a case, renaming one, or reading a value written by a newer build never trips a
/// migration. Each model exposes a typed computed property over the stored string, so
/// call sites still get type safety.

/// Remli captures two things. Ideas get the full treatment — categorised, embedded,
/// linked to other ideas. Tasks are the quick "remind me to call the dentist" captures
/// that would only pollute the idea graph, so they skip enrichment and just carry a date.
enum IdeaKind: String, Codable, CaseIterable, Sendable {
    case idea
    case task

    var label: String {
        switch self {
        case .idea: return "Idea"
        case .task: return "To-do"
        }
    }

    var symbolName: String {
        switch self {
        case .idea: return "lightbulb"
        case .task: return "checkmark.circle"
        }
    }
}

/// Where an idea is in its life. Drives both the resurfacing score and how the idea is
/// drawn in the graph.
enum IdeaStatus: String, Codable, CaseIterable, Sendable {
    /// Captured, not yet acted on. The default.
    case seed
    /// Being worked on now.
    case active
    /// Deliberately set aside. Parked ideas are surfaced far less often than seeds.
    case parked
    /// Finished.
    case done

    var label: String {
        switch self {
        case .seed: return "Seed"
        case .active: return "Active"
        case .parked: return "Parked"
        case .done: return "Done"
        }
    }

    var symbolName: String {
        switch self {
        case .seed: return "circle.dotted"
        case .active: return "circle.lefthalf.filled"
        case .parked: return "pause.circle"
        case .done: return "checkmark.circle.fill"
        }
    }
}

enum CaptureMode: String, Codable, CaseIterable, Sendable {
    case text
    case voice
}

/// The type of an edge between two ideas.
///
/// This is what separates Remli from "related notes". A generic similarity score tells you
/// two ideas are near each other; these say *how*, and two of them are directional in a
/// way that makes a dependency graph possible.
enum LinkKind: String, Codable, CaseIterable, Sendable {
    /// Same territory, no dependency. Undirected in meaning.
    case relatesTo
    /// The source extends or elaborates the target.
    case buildsOn
    /// The source must happen before the target can. This is the edge that makes the
    /// "path to completion" view real rather than decorative.
    case prerequisiteFor
    /// Another take on the same underlying idea.
    case variantOf
    /// The two ideas pull in opposite directions — worth knowing before acting on either.
    case contradicts

    var label: String {
        switch self {
        case .relatesTo: return "Relates to"
        case .buildsOn: return "Builds on"
        case .prerequisiteFor: return "Unlocks"
        case .variantOf: return "Variant of"
        case .contradicts: return "Tension with"
        }
    }

    /// Whether the edge implies an ordering. Only directed edges take part in path finding.
    var isDirected: Bool {
        switch self {
        case .buildsOn, .prerequisiteFor: return true
        case .relatesTo, .variantOf, .contradicts: return false
        }
    }

    var symbolName: String {
        switch self {
        case .relatesTo: return "link"
        case .buildsOn: return "arrow.up.forward"
        case .prerequisiteFor: return "key"
        case .variantOf: return "square.on.square"
        case .contradicts: return "bolt.trianglebadge.exclamationmark"
        }
    }
}
