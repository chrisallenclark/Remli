import CoreGraphics
import Foundation

/// Where a hub's ideas sit once you focus it.
///
/// Separated from the view and kept pure for one reason: this arithmetic is the whole of
/// the focus interaction, it is being written without a simulator to look at, and a ring
/// that quietly puts half its nodes off the edge of the screen is indistinguishable from a
/// broken map. Here it can be tested.
///
/// Everything is in **view** space, not graph space. The orbit is an arrangement on the
/// screen in front of you, not a rearrangement of the underlying layout — the layout is
/// still there, unchanged, waiting behind the transition.
enum MapFocusLayout {

    struct Satellite: Equatable, Sendable {
        let id: UUID
        /// 0–1, from the link joining it to the hub.
        let strength: Double

        init(id: UUID, strength: Double) {
            self.id = id
            self.strength = min(max(strength, 0), 1)
        }
    }

    /// How much of the shorter screen dimension the ring may claim, measured from the
    /// centre and including the widest satellite. Leaves a margin so nothing clips.
    static let maxExtentFraction: CGFloat = 0.5

    /// Vertical squash. A perfect circle in a portrait canvas wastes the width and crowds
    /// the top and bottom, where the filter chips and the card already are.
    static let verticalSquash: CGFloat = 0.86

    /// The furthest a satellite sits, as a multiple of the ring, at strength 0.
    static let farthest: CGFloat = 1.18
    /// How much of that a full-strength link pulls back. Stronger sits closer.
    static let pullIn: CGFloat = 0.30

    /// The smallest real gap a satellite can end up at, as a fraction of the ring: pulled
    /// fully in by a strong link *and* sitting at the squashed top or bottom of the ellipse.
    static var closestApproach: CGFloat { (farthest - pullIn) * verticalSquash }

    /// Positions for the hub and each of its satellites.
    ///
    /// Satellites are ordered by strength, strongest first, starting at the top and going
    /// clockwise — so the arrangement itself says which relationship matters most, before
    /// you read a single label. Ties break on identifier so the ring is stable between
    /// launches rather than reshuffling every time you tap.
    static func positions(
        hub: UUID,
        satellites: [Satellite],
        centre: CGPoint,
        hubRadius: CGFloat,
        satelliteRadius: (UUID) -> CGFloat,
        in size: CGSize
    ) -> [UUID: CGPoint] {
        var result: [UUID: CGPoint] = [hub: centre]
        guard !satellites.isEmpty else { return result }

        let ordered = satellites.sorted { lhs, rhs in
            if lhs.strength == rhs.strength { return lhs.id.uuidString < rhs.id.uuidString }
            return lhs.strength > rhs.strength
        }

        let widest = ordered.map { satelliteRadius($0.id) }.max() ?? 0

        // Clearance first: whatever else happens, a satellite must not sit on top of the
        // hub. Then a comfortable gap if there is room, then whatever the screen allows.
        //
        // Both bounds are divided by the two factors that shrink the real gap below the
        // nominal one: `closest`, because the strongest link is pulled inside the ring, and
        // `verticalSquash`, because a satellite at the top or bottom is nearer than its
        // distance suggests. Sizing against the hub directly lets a strong satellite land
        // on top of the very thing it is attached to — which a cramped screen produces
        // reliably, and which no amount of looking at a laptop would have caught.
        let tightest = closestApproach
        let minimum = (hubRadius + widest + 8) / tightest
        let preferred = (hubRadius + widest + 34) / tightest
        let halfShort = min(size.width, size.height) * maxExtentFraction
        let ceiling = max((halfShort - widest - 12) / farthest, minimum)
        let ring = max(minimum, min(preferred, ceiling))

        for (index, satellite) in ordered.enumerated() {
            let angle = (Double(index) / Double(ordered.count)) * 2 * .pi - .pi / 2
            let distance = ring * (farthest - pullIn * CGFloat(satellite.strength))
            result[satellite.id] = CGPoint(
                x: centre.x + cos(angle) * distance,
                y: centre.y + sin(angle) * distance * verticalSquash
            )
        }

        return result
    }

    /// Where an idea unrelated to the hub goes: pushed outward along the line it already
    /// sits on, so it leaves the middle clear without teleporting somewhere meaningless.
    /// It keeps its bearing, which is what lets it come back to the right place on release.
    static func pushedAside(_ home: CGPoint, centre: CGPoint, in size: CGSize) -> CGPoint {
        let delta = CGPoint(x: home.x - centre.x, y: home.y - centre.y)
        let distance = max(hypot(delta.x, delta.y), 0.01)
        let limit = min(size.width, size.height) * 0.62
        let pushed = min(distance * 1.18, limit)
        return CGPoint(
            x: centre.x + delta.x / distance * pushed,
            y: centre.y + delta.y / distance * pushed
        )
    }
}
