import Foundation
import SwiftData

/// A typed, explained edge between two ideas.
///
/// The `rationale` is the whole point. Plenty of apps can tell you two notes are similar;
/// almost none can tell you *why*, and an unexplained connection is not something you can
/// act on or trust. Every link therefore carries a sentence, and the UI always shows it.
@Model
final class IdeaLink {

    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var kindRaw: String = LinkKind.relatesTo.rawValue

    /// One sentence, written by the intelligence layer, saying why these two belong
    /// together. Shown verbatim when the user taps the edge.
    var rationale: String = ""

    /// 0–1. Drives edge opacity and thickness in the graph, and filters out weak noise.
    var strength: Double = 0

    /// Set when the user explicitly keeps a suggested link. Confirmed links are never
    /// pruned by later passes.
    var confirmedByUser: Bool = false

    var source: Idea?
    var target: Idea?

    init(
        source: Idea?,
        target: Idea?,
        kind: LinkKind,
        rationale: String,
        strength: Double
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.source = source
        self.target = target
        self.kindRaw = kind.rawValue
        self.rationale = rationale
        self.strength = min(max(strength, 0), 1)
    }
}

extension IdeaLink {
    var kind: LinkKind {
        get { LinkKind(rawValue: kindRaw) ?? .relatesTo }
        set { kindRaw = newValue.rawValue }
    }

    /// Given one end of the link, the idea at the other end.
    func other(than idea: Idea) -> Idea? {
        if source?.id == idea.id { return target }
        if target?.id == idea.id { return source }
        return nil
    }

    /// A stable key for de-duplication. Undirected kinds sort their endpoints so that
    /// A→B and B→A collapse to the same key, while directed kinds keep their order.
    var dedupeKey: String {
        let a = source?.id.uuidString ?? "?"
        let b = target?.id.uuidString ?? "?"
        if kind.isDirected {
            return "\(kindRaw):\(a)->\(b)"
        }
        let ends = [a, b].sorted()
        return "\(kindRaw):\(ends[0])~\(ends[1])"
    }
}
