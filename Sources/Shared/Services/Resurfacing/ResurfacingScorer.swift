import Foundation

/// A flattened idea, for scoring. Pure values — no SwiftData, no main actor.
struct ResurfacingCandidate: Equatable, Sendable {
    var id: UUID
    var importance: Double
    var createdAt: Date
    var lastSurfacedAt: Date?
    var surfaceCount: Int
    var status: IdeaStatus
    var pinned: Bool
    var estimatedMinutes: Int
}

/// Decides which idea to bring back, and when.
///
/// Deliberately deterministic rather than asking a model. Three reasons: it has to run in
/// a background task where a model call may not be affordable; it must be testable; and
/// the behaviour needs to be predictable enough that the user can build trust in it. A
/// notification that feels arbitrary gets the app's notifications turned off.
enum ResurfacingScorer {

    /// Ideas younger than this are left alone. You do not need reminding of a thought you
    /// had this morning, and interrupting someone with it is the fastest way to make the
    /// feature feel stupid.
    static let minimumAgeHours: Double = 20

    /// Once an idea has been shown this many times without being acted on, it stops
    /// competing. Nagging is not a feature.
    static let surfaceFatigueLimit = 6

    static func score(_ candidate: ResurfacingCandidate, now: Date = .now) -> Double {
        // Finished ideas are never resurfaced.
        guard candidate.status != .done else { return 0 }

        let ageHours = now.timeIntervalSince(candidate.createdAt) / 3600
        guard ageHours >= minimumAgeHours else { return 0 }
        guard candidate.surfaceCount < surfaceFatigueLimit else { return 0 }

        // How long since it was last in front of you. Rises quickly over the first week,
        // then flattens — an idea untouched for two months is not twice as urgent as one
        // untouched for one.
        let referenceDate = candidate.lastSurfacedAt ?? candidate.createdAt
        let daysSinceSeen = now.timeIntervalSince(referenceDate) / 86400
        let staleness = min(1, log(1 + max(0, daysSinceSeen)) / log(15))

        // Ideas that have already been shown a few times get progressively less weight.
        let novelty = 1 / (1 + Double(candidate.surfaceCount) * 0.6)

        // Something captured a year ago and never touched is usually gone cold. This
        // gently favours the last couple of months without hard-cutting anything.
        let ageDays = ageHours / 24
        let recencyOfCapture = ageDays <= 90 ? 1.0 : max(0.45, 1 - (ageDays - 90) / 500)

        // Split into named terms rather than one expression: the type checker times out
        // on a four-way sum of mixed literals and computed Doubles, and this is easier to
        // reason about anyway.
        let importanceTerm: Double = candidate.importance * 0.35
        let stalenessTerm: Double = staleness * 0.30
        let noveltyTerm: Double = novelty * 0.20
        let recencyTerm: Double = recencyOfCapture * 0.15

        var score: Double = importanceTerm + stalenessTerm
        score += noveltyTerm + recencyTerm
        score *= statusWeight(candidate.status)

        if candidate.pinned {
            // A pin is the user explicitly saying "keep this in front of me", which should
            // outrank the model's opinion of importance.
            score = min(1, score + 0.20)
        }

        return max(0, min(1, score))
    }

    private static func statusWeight(_ status: IdeaStatus) -> Double {
        switch status {
        case .active: return 1.15   // already in motion — most likely to be picked up
        case .seed: return 1.0
        case .parked: return 0.35   // deliberately set aside; surface rarely, not never
        case .done: return 0
        }
    }

    /// A candidate paired with its score.
    ///
    /// A named type rather than an inline tuple: chaining map/filter/sorted/prefix over an
    /// anonymous labelled tuple is enough to time out the expression type checker.
    private struct Scored {
        var candidate: ResurfacingCandidate
        var value: Double
    }

    /// Highest-scoring ideas first, dropping anything scoring zero.
    static func rank(
        _ candidates: [ResurfacingCandidate],
        now: Date = .now,
        limit: Int = .max
    ) -> [ResurfacingCandidate] {
        var scored: [Scored] = []
        scored.reserveCapacity(candidates.count)

        for candidate in candidates {
            let value = score(candidate, now: now)
            if value > 0 {
                scored.append(Scored(candidate: candidate, value: value))
            }
        }

        // Ties broken by id so ordering is stable across runs rather than dependent on
        // fetch order.
        scored.sort { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.candidate.id.uuidString < rhs.candidate.id.uuidString
            }
            return lhs.value > rhs.value
        }

        let capped = limit < scored.count ? Array(scored[0..<limit]) : scored
        return capped.map(\.candidate)
    }

    /// The best idea for a specific window of free time.
    ///
    /// Fit matters more than raw score here: suggesting a two-day project for a
    /// twenty-minute gap is worse than suggesting a merely decent idea that actually fits.
    static func bestFit(
        _ candidates: [ResurfacingCandidate],
        availableMinutes: Int,
        now: Date = .now
    ) -> ResurfacingCandidate? {
        let ranked = rank(candidates, now: now)

        var fitting: [ResurfacingCandidate] = []
        for candidate in ranked {
            let minutes = candidate.estimatedMinutes
            if minutes > 0 && minutes <= availableMinutes {
                fitting.append(candidate)
            }
        }

        // Among those that fit, prefer the one using the window most fully, falling back
        // to score when two are similarly sized.
        return fitting.max { lhs, rhs in
            let lhsFit = Double(lhs.estimatedMinutes) / Double(availableMinutes)
            let rhsFit = Double(rhs.estimatedMinutes) / Double(availableMinutes)
            if abs(lhsFit - rhsFit) > 0.15 {
                return lhsFit < rhsFit
            }
            return score(lhs, now: now) < score(rhs, now: now)
        }
    }
}

extension ResurfacingCandidate {
    init(_ idea: Idea) {
        self.id = idea.id
        // Your figure, not the model's, wherever you have given one. This is where an
        // importance override earns its keep: marking something Major is what makes it
        // start coming back, and marking it Passing is what makes it stop.
        self.importance = idea.importance
        self.createdAt = idea.createdAt
        self.lastSurfacedAt = idea.lastSurfacedAt
        self.surfaceCount = idea.surfaceCount
        self.status = idea.status
        self.pinned = idea.pinned
        self.estimatedMinutes = idea.estimatedMinutes
    }
}
