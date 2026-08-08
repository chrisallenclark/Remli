import Foundation

/// How much an idea matters, as a person would say it.
///
/// The stored score is a `Double` because everything that ranks ideas needs to sort them,
/// but a 0–1 slider is a machine dial pretending to be a question — nobody knows whether
/// their idea is a 0.63 or a 0.71, and being asked implies a precision that does not exist.
/// Four named steps is a judgement someone can actually make in a second.
///
/// The scores are spaced so that a level change is a real change in resurfacing behaviour
/// rather than a nudge, and `.matters` sits near where enrichment's guesses cluster.
enum ImportanceLevel: String, CaseIterable, Identifiable, Sendable {
    case passing
    case worthKeeping
    case matters
    case major

    var id: String { rawValue }

    var score: Double {
        switch self {
        case .passing: return 0.15
        case .worthKeeping: return 0.40
        case .matters: return 0.65
        case .major: return 0.90
        }
    }

    var name: String {
        switch self {
        case .passing: return "Passing"
        case .worthKeeping: return "Worth keeping"
        case .matters: return "Matters"
        case .major: return "Major"
        }
    }

    /// One line saying what choosing this actually does, since the whole point of showing
    /// the score is that changing it has consequences you can predict.
    var effect: String {
        switch self {
        case .passing: return "Kept, but Remli will stop bringing it up."
        case .worthKeeping: return "Comes back occasionally."
        case .matters: return "Comes back regularly, and sits large on the map."
        case .major: return "Near the front of every review."
        }
    }

    /// The level a raw score falls into. Nearest by distance rather than by threshold, so
    /// a guess of 0.70 reads as *Matters* rather than being rounded down by an arbitrary
    /// cut-off. Ties fall to the lower level, which is the conservative direction.
    static func nearest(to score: Double) -> ImportanceLevel {
        allCases.min { abs($0.score - score) < abs($1.score - score) } ?? .worthKeeping
    }
}
