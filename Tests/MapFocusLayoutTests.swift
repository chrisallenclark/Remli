import CoreGraphics
import Foundation
import Testing

@testable import Remli

/// The focus ring is written without a simulator to look at, and a ring that quietly puts
/// half its satellites off the edge of the screen is indistinguishable from a broken map.
/// These are the checks a pair of eyes would otherwise be doing.
@Suite("Map focus layout")
struct MapFocusLayoutTests {

    private let phone = CGSize(width: 390, height: 620)

    private func satellites(_ strengths: [Double]) -> [MapFocusLayout.Satellite] {
        strengths.map { MapFocusLayout.Satellite(id: UUID(), strength: $0) }
    }

    @Test("The hub sits at the centre")
    func hubIsCentred() {
        let hub = UUID()
        let centre = CGPoint(x: 195, y: 300)
        let result = MapFocusLayout.positions(
            hub: hub,
            satellites: satellites([0.5, 0.8]),
            centre: centre,
            hubRadius: 40,
            satelliteRadius: { _ in 24 },
            in: phone
        )
        #expect(result[hub] == centre)
    }

    @Test("Every satellite gets a position, and only the satellites")
    func placesEveryone() {
        let hub = UUID()
        let sats = satellites([0.9, 0.6, 0.3, 0.1])
        let result = MapFocusLayout.positions(
            hub: hub,
            satellites: sats,
            centre: CGPoint(x: 195, y: 300),
            hubRadius: 40,
            satelliteRadius: { _ in 24 },
            in: phone
        )
        #expect(result.count == sats.count + 1)
        for satellite in sats {
            #expect(result[satellite.id] != nil)
        }
    }

    @Test("A stronger link sits closer to the hub than a weaker one")
    func strengthPullsIn() throws {
        let hub = UUID()
        let strong = MapFocusLayout.Satellite(id: UUID(), strength: 0.95)
        let weak = MapFocusLayout.Satellite(id: UUID(), strength: 0.10)
        let centre = CGPoint(x: 195, y: 300)

        let result = MapFocusLayout.positions(
            hub: hub,
            satellites: [strong, weak],
            centre: centre,
            hubRadius: 40,
            satelliteRadius: { _ in 24 },
            in: phone
        )

        let strongPoint = try #require(result[strong.id])
        let weakPoint = try #require(result[weak.id])

        // Compare on the unsquashed radius so the ellipse does not confuse the comparison.
        func reach(_ point: CGPoint) -> CGFloat {
            let dx = point.x - centre.x
            let dy = (point.y - centre.y) / MapFocusLayout.verticalSquash
            return hypot(dx, dy)
        }

        #expect(reach(strongPoint) < reach(weakPoint))
    }

    @Test("No satellite overlaps the hub, however cramped the screen")
    func alwaysClearsTheHub() throws {
        let hub = UUID()
        let centre = CGPoint(x: 100, y: 100)
        let hubRadius: CGFloat = 46
        let satelliteRadius: CGFloat = 42
        let sats = satellites([1, 1, 1, 1, 1, 1])

        // Deliberately far too small for the ring it would like to draw.
        let cramped = CGSize(width: 200, height: 200)

        let result = MapFocusLayout.positions(
            hub: hub,
            satellites: sats,
            centre: centre,
            hubRadius: hubRadius,
            satelliteRadius: { _ in satelliteRadius },
            in: cramped
        )

        for satellite in sats {
            let point = try #require(result[satellite.id])
            let distance = hypot(point.x - centre.x, point.y - centre.y)
            #expect(
                distance >= hubRadius + satelliteRadius,
                "a satellite overlapped the hub at \(distance)pt"
            )
        }
    }

    @Test("Satellites stay on screen at realistic sizes")
    func staysOnScreen() throws {
        let hub = UUID()
        let centre = CGPoint(x: phone.width / 2, y: phone.height / 2)
        let sats = satellites([1, 0.8, 0.6, 0.4, 0.2, 0])

        let result = MapFocusLayout.positions(
            hub: hub,
            satellites: sats,
            centre: centre,
            // The largest a node can be: 16 + 30 at full anchor.
            hubRadius: 46,
            satelliteRadius: { _ in 42 },
            in: phone
        )

        for satellite in sats {
            let point = try #require(result[satellite.id])
            #expect(point.x - 42 >= 0, "clipped off the left edge")
            #expect(point.x + 42 <= phone.width, "clipped off the right edge")
            #expect(point.y - 42 >= 0, "clipped off the top")
            #expect(point.y + 42 <= phone.height, "clipped off the bottom")
        }
    }

    @Test("Equal strengths still produce a stable order between launches")
    func stableOrdering() throws {
        let hub = UUID()
        let a = MapFocusLayout.Satellite(id: UUID(), strength: 0.5)
        let b = MapFocusLayout.Satellite(id: UUID(), strength: 0.5)
        let centre = CGPoint(x: 195, y: 300)

        let first = MapFocusLayout.positions(
            hub: hub, satellites: [a, b], centre: centre,
            hubRadius: 40, satelliteRadius: { _ in 24 }, in: phone
        )
        let second = MapFocusLayout.positions(
            hub: hub, satellites: [b, a], centre: centre,
            hubRadius: 40, satelliteRadius: { _ in 24 }, in: phone
        )

        #expect(try #require(first[a.id]) == (try #require(second[a.id])))
        #expect(try #require(first[b.id]) == (try #require(second[b.id])))
    }

    @Test("A hub with nothing attached is just the hub")
    func lonelyHub() {
        let hub = UUID()
        let result = MapFocusLayout.positions(
            hub: hub, satellites: [], centre: .zero,
            hubRadius: 30, satelliteRadius: { _ in 20 }, in: phone
        )
        #expect(result.count == 1)
    }

    @Test("Pushing an idea aside keeps its bearing and stays bounded")
    func pushAsideKeepsBearing() {
        let centre = CGPoint(x: 195, y: 300)
        let home = CGPoint(x: 245, y: 300)
        let pushed = MapFocusLayout.pushedAside(home, centre: centre, in: phone)

        #expect(pushed.y == centre.y, "bearing changed")
        #expect(pushed.x > home.x, "did not move outward")

        let far = CGPoint(x: 5_000, y: 300)
        let clamped = MapFocusLayout.pushedAside(far, centre: centre, in: phone)
        #expect(clamped.x - centre.x <= min(phone.width, phone.height) * 0.62 + 0.001)
    }
}
