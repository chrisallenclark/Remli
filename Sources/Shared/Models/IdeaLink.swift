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

    /// How sure the model was, separate from how strong it thinks the relationship is.
    /// Strength answers "how closely are these related"; confidence answers "how much
    /// should you trust me about that". Auto-accept keys off this one.
    var confidence: Double = 1

    /// Who made this link — `ai` or `user`.
    var originRaw: String = LinkOrigin.ai.rawValue

    /// Whether the link is waiting on a decision.
    ///
    /// **Defaults to accepted, deliberately.** Every link already on a device was created
    /// silently under the old behaviour, and defaulting to pending would turn an existing
    /// graph into an inbox of dozens of questions on first launch after updating — the
    /// change would read as a bug rather than a feature.
    var reviewStateRaw: String = LinkReviewState.accepted.rawValue

    var source: Idea?
    var target: Idea?

    init(
        source: Idea?,
        target: Idea?,
        kind: LinkKind,
        rationale: String,
        strength: Double,
        confidence: Double = 1,
        origin: LinkOrigin = .ai,
        reviewState: LinkReviewState = .accepted
    ) {
        self.id = UUID()
        self.createdAt = .now
        self.source = source
        self.target = target
        self.kindRaw = kind.rawValue
        self.rationale = rationale
        self.strength = min(max(strength, 0), 1)
        self.confidence = min(max(confidence, 0), 1)
        self.originRaw = origin.rawValue
        self.reviewStateRaw = reviewState.rawValue
    }
}

extension IdeaLink {
    var kind: LinkKind {
        get { LinkKind(rawValue: kindRaw) ?? .relatesTo }
        set { kindRaw = newValue.rawValue }
    }

    var origin: LinkOrigin {
        get { LinkOrigin(rawValue: originRaw) ?? .ai }
        set { originRaw = newValue.rawValue }
    }

    var reviewState: LinkReviewState {
        get { LinkReviewState(rawValue: reviewStateRaw) ?? .accepted }
        set { reviewStateRaw = newValue.rawValue }
    }

    /// Whether this link should be treated as real — drawn on the map, counted in a
    /// roadmap, shown as fact. A proposal is none of those things until you say so.
    var isActive: Bool { reviewState == .accepted }

    /// Keeps the link, permanently. Accepted links are never pruned by later passes.
    func accept() {
        reviewState = .accepted
        confirmedByUser = true
    }

    /// Rejects it. The record is kept rather than deleted so the same pair is never
    /// proposed again — a suggestion you have already turned down coming back is the
    /// fastest way to make someone stop reading suggestions.
    func reject() {
        reviewState = .rejected
        confirmedByUser = true
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
