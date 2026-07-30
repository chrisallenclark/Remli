import SwiftData
import SwiftUI

/// The connections for one idea.
///
/// The reason is shown, always, and given more visual weight than the relationship label.
/// A connection you have to take on faith is one you stop trusting; a connection that
/// tells you what it noticed is one you can agree or disagree with.
struct ConnectionsSection: View {

    let idea: Idea

    private var links: [IdeaLink] {
        idea.allLinks
            .filter { $0.other(than: idea) != nil }
            .sorted { $0.strength > $1.strength }
    }

    var body: some View {
        if !links.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                Text("CONNECTIONS")
                    .font(Theme.Typography.sectionLabel)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .tracking(0.6)

                ForEach(links) { link in
                    if let other = link.other(than: idea) {
                        NavigationLink {
                            IdeaDetailView(idea: other)
                        } label: {
                            ConnectionRow(link: link, other: other, from: idea)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ConnectionRow: View {

    let link: IdeaLink
    let other: Idea
    let from: Idea

    /// Directed relationships read differently depending on which end you are standing at:
    /// from the source "unlocks", from the target "unlocked by". Showing the source's
    /// wording on both ends would be actively misleading.
    private var relationshipLabel: String {
        let isSource = link.source?.id == from.id
        guard link.kind.isDirected, !isSource else { return link.kind.label }

        switch link.kind {
        case .prerequisiteFor: return "Unlocked by"
        case .buildsOn: return "Built on by"
        default: return link.kind.label
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            HStack(spacing: Theme.Space.xxs) {
                Image(systemName: link.kind.symbolName)
                    .font(.system(size: 10, weight: .medium))
                Text(relationshipLabel.uppercased())
                    .font(Theme.Typography.meta)
                    .tracking(0.4)

                Spacer(minLength: 0)

                StrengthPips(strength: link.strength)
            }
            .foregroundStyle(Theme.Palette.inkMuted)

            Text(other.displayTitle)
                .font(Theme.Typography.ideaBody)
                .foregroundStyle(Theme.Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(link.rationale)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

/// Three pips rather than a number — the strength is a rough judgement, and showing "0.72"
/// would imply a precision the model does not have.
private struct StrengthPips: View {
    let strength: Double

    private var filled: Int {
        max(1, min(3, Int((strength * 3).rounded(.up))))
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < filled ? Theme.Palette.ember : Theme.Palette.hairline)
                    .frame(width: 4, height: 4)
            }
        }
    }
}
