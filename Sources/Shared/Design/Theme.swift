import SwiftUI

/// Remli's design system.
///
/// Everything visual comes from here so the app stays one coherent object rather than a
/// pile of ad-hoc paddings. Colours live in the asset catalog with genuine light and dark
/// values, so the whole app follows the system appearance without a single `colorScheme`
/// check in view code.
enum Theme {

    // MARK: - Colour

    /// Colours are referenced by name so they resolve through the asset catalog and pick
    /// up the correct light/dark variant automatically.
    enum Palette {
        static let canvas = Color("Canvas", bundle: .main)
        static let surface = Color("Surface", bundle: .main)
        static let ink = Color("Ink", bundle: .main)
        static let inkMuted = Color("InkMuted", bundle: .main)
        static let hairline = Color("Hairline", bundle: .main)
        static let ember = Color("Ember", bundle: .main)
    }

    // MARK: - Spacing

    /// A 4pt scale. Using named steps rather than magic numbers keeps rhythm consistent
    /// across screens built at different times.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let pill: CGFloat = 999
    }

    // MARK: - Type

    /// Idea text is set in a serif (New York) because it reads as writing rather than
    /// interface. Everything structural stays in SF Pro.
    enum Typography {
        static let display = Font.system(.largeTitle, design: .serif, weight: .regular)
        static let title = Font.system(.title2, design: .serif, weight: .regular)
        static let ideaBody = Font.system(.body, design: .serif)
        static let sectionLabel = Font.system(.footnote, weight: .medium)
        static let meta = Font.system(.caption)
        static let control = Font.system(.subheadline, weight: .medium)
    }

    // MARK: - Motion

    enum Motion {
        /// The default for anything the user directly caused. Settles quickly, no bounce
        /// overshoot that would read as toy-like.
        static let standard = Animation.spring(response: 0.34, dampingFraction: 0.82)
        /// For larger transitions such as a card expanding into a detail view.
        static let expressive = Animation.spring(response: 0.46, dampingFraction: 0.78)
    }
}

// MARK: - Reusable surfaces

/// A raised card. Used for idea rows and any grouped content.
struct CardBackground: ViewModifier {
    var padding: CGFloat = Theme.Space.md

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardBackground(padding: CGFloat = Theme.Space.md) -> some View {
        modifier(CardBackground(padding: padding))
    }
}
