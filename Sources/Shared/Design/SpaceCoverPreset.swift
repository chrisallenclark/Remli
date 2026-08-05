import SwiftUI

/// Ready-made covers for a Space, for when you have no photo you want to use.
///
/// **These are designed, not photographed.** Shipping thirty stock photographs would mean
/// thirty licences, several megabytes in the binary, and a set that still misses whatever
/// someone names their Space next week. Designed covers sidestep all three: they weigh
/// nothing, they are legally ours, and — the part that actually matters — they were drawn
/// as a family, so a grid of six never looks like six different apps.
///
/// They are grouped by the kind of Space they suit, so the picker can lead with the three
/// or four that fit rather than presenting a wall of thirty.
struct SpaceCoverPreset: Identifiable, Hashable, Sendable {

    /// Stored on the Space, so it must never change once shipped.
    let id: String
    let name: String
    let group: Group
    /// Top-left, bottom-right. The wash and ramp in `SpaceCover` go over the top.
    let colors: [String]
    let style: Style

    enum Group: String, CaseIterable, Sendable {
        case business = "Business"
        case creative = "Creative"
        case health = "Health"
        case learning = "Learning"
        case music = "Music"
        case personal = "Personal"
        case money = "Money"
        case food = "Food"
        case places = "Places"
        case technical = "Technical"
    }

    /// How the colours are arranged. Four treatments rather than thirty one-offs — the
    /// variety comes from colour, and the shared geometry is what makes them a set.
    enum Style: String, Sendable {
        /// A straight diagonal wash. The quiet one.
        case wash
        /// Concentric arcs from a corner, like a horizon.
        case horizon
        /// A soft bloom off-centre, like light through a window.
        case glow
        /// Layered diagonal bands.
        case strata
    }
}

extension SpaceCoverPreset {

    /// Thirty covers, three per group.
    ///
    /// Colours are drawn from the same restricted palette family the categories use, pushed
    /// a little further apart in hue so two Spaces sitting side by side never read as the
    /// same place.
    static let all: [SpaceCoverPreset] = [
        // Business
        .init(id: "biz.ledger", name: "Ledger", group: .business, colors: ["1F3A44", "3E6F72"], style: .strata),
        .init(id: "biz.storefront", name: "Storefront", group: .business, colors: ["6E4630", "C08A5A"], style: .horizon),
        .init(id: "biz.boardroom", name: "Boardroom", group: .business, colors: ["2C2F45", "5A5E85"], style: .wash),

        // Creative
        .init(id: "cre.studio", name: "Studio", group: .creative, colors: ["7A3350", "C4707F"], style: .glow),
        .init(id: "cre.canvas", name: "Canvas", group: .creative, colors: ["8A5A20", "D9AE6A"], style: .wash),
        .init(id: "cre.darkroom", name: "Darkroom", group: .creative, colors: ["3A2140", "7D4E86"], style: .glow),

        // Health
        .init(id: "hea.track", name: "Track", group: .health, colors: ["1F5C4A", "5EA98A"], style: .strata),
        .init(id: "hea.sunrise", name: "Sunrise", group: .health, colors: ["9A4A22", "E0A05E"], style: .horizon),
        .init(id: "hea.stillwater", name: "Still Water", group: .health, colors: ["1E4A5C", "6FA6B8"], style: .wash),

        // Learning
        .init(id: "lea.library", name: "Library", group: .learning, colors: ["4A3524", "9C7A52"], style: .strata),
        .init(id: "lea.lecture", name: "Lecture", group: .learning, colors: ["2B3D5C", "6B85B0"], style: .wash),
        .init(id: "lea.margin", name: "Margin Notes", group: .learning, colors: ["5C4A2E", "B39A6A"], style: .glow),

        // Music
        .init(id: "mus.stage", name: "Stage", group: .music, colors: ["3B1F4E", "8B5AA6"], style: .glow),
        .init(id: "mus.vinyl", name: "Vinyl", group: .music, colors: ["24242C", "5E5E70"], style: .horizon),
        .init(id: "mus.amber", name: "Amber Room", group: .music, colors: ["6B3A12", "D08A3C"], style: .glow),

        // Personal
        .init(id: "per.hearth", name: "Hearth", group: .personal, colors: ["6B3520", "C67F52"], style: .glow),
        .init(id: "per.dusk", name: "Dusk", group: .personal, colors: ["3A3550", "8079A6"], style: .horizon),
        .init(id: "per.linen", name: "Linen", group: .personal, colors: ["5C5145", "A99883"], style: .wash),

        // Money
        .init(id: "mon.market", name: "Market", group: .money, colors: ["1C4A3C", "4E9179"], style: .strata),
        .init(id: "mon.vault", name: "Vault", group: .money, colors: ["2A2E33", "646D77"], style: .wash),
        .init(id: "mon.gold", name: "Gold Hour", group: .money, colors: ["6F5218", "C9A45C"], style: .horizon),

        // Food
        .init(id: "foo.kitchen", name: "Kitchen", group: .food, colors: ["6E3A24", "C4835C"], style: .glow),
        .init(id: "foo.harvest", name: "Harvest", group: .food, colors: ["5E5A1E", "AEA85A"], style: .strata),
        .init(id: "foo.spice", name: "Spice", group: .food, colors: ["7A2F1E", "C9704A"], style: .wash),

        // Places
        .init(id: "pla.coast", name: "Coast", group: .places, colors: ["1D4A5A", "63A3B5"], style: .horizon),
        .init(id: "pla.ridge", name: "Ridge", group: .places, colors: ["4A3A2E", "9C8168"], style: .horizon),
        .init(id: "pla.citynight", name: "City at Night", group: .places, colors: ["1A1F33", "4E5B87"], style: .glow),

        // Technical
        .init(id: "tec.circuit", name: "Circuit", group: .technical, colors: ["1E3540", "4F7E8C"], style: .strata),
        .init(id: "tec.terminal", name: "Terminal", group: .technical, colors: ["1C2A22", "4E7A5E"], style: .wash),
        .init(id: "tec.signal", name: "Signal", group: .technical, colors: ["2E2350", "6E5AA6"], style: .glow),
    ]

    static func preset(id: String?) -> SpaceCoverPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func grouped() -> [(group: Group, presets: [SpaceCoverPreset])] {
        Group.allCases.map { group in
            (group, all.filter { $0.group == group })
        }
    }

    var startColor: Color { Color(hex: colors[0]) ?? Theme.Palette.ember }
    var endColor: Color { Color(hex: colors[1]) ?? Theme.Palette.ember }
}

/// Draws a preset. Kept separate from `SpaceCover` so the picker can show a preset without
/// dragging a `IdeaCategory` along with it.
struct SpaceCoverPresetArt: View {
    let preset: SpaceCoverPreset

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [preset.startColor, preset.endColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            switch preset.style {
            case .wash:
                EmptyView()

            case .horizon:
                // Concentric arcs rising from the bottom-left, read as land or water.
                GeometryReader { proxy in
                    ZStack {
                        ForEach(0..<3, id: \.self) { index in
                            let inset = CGFloat(index) * proxy.size.height * 0.22
                            Ellipse()
                                .fill(.white.opacity(0.06))
                                .frame(
                                    width: proxy.size.width * 1.8,
                                    height: proxy.size.height * 1.1
                                )
                                .offset(
                                    x: -proxy.size.width * 0.4,
                                    y: proxy.size.height * 0.55 + inset
                                )
                        }
                    }
                }

            case .glow:
                RadialGradient(
                    colors: [.white.opacity(0.26), .clear],
                    center: UnitPoint(x: 0.72, y: 0.28),
                    startRadius: 0,
                    endRadius: 190
                )

            case .strata:
                // Diagonal bands, evenly spaced — structure without a motif.
                GeometryReader { proxy in
                    ZStack {
                        ForEach(0..<4, id: \.self) { index in
                            Rectangle()
                                .fill(.white.opacity(0.05))
                                .frame(width: proxy.size.width * 2, height: 16)
                                .rotationEffect(.degrees(-24))
                                .offset(y: CGFloat(index) * 42 - proxy.size.height * 0.18)
                        }
                    }
                }
            }
        }
    }
}
