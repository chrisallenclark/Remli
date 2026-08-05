import SwiftData
import SwiftUI

/// The connections for one idea.
///
/// The reason is shown, always, and given more visual weight than the relationship label.
/// A connection you have to take on faith is one you stop trusting; a connection that
/// tells you what it noticed is one you can agree or disagree with.
struct ConnectionsSection: View {

    let idea: Idea

    private var usable: [IdeaLink] {
        idea.allLinks.filter { $0.other(than: idea) != nil }
    }

    private var accepted: [IdeaLink] {
        usable.filter { $0.reviewState == .accepted }.sorted { $0.strength > $1.strength }
    }

    private var pending: [IdeaLink] {
        usable.filter { $0.reviewState == .pending }.sorted { $0.strength > $1.strength }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.lg) {
            // Proposals first. They are the thing asking for something.
            if !pending.isEmpty {
                section(title: "REMLI NOTICED", links: pending, isProposal: true)
            }

            if !accepted.isEmpty {
                section(title: "CONNECTIONS", links: accepted, isProposal: false)
            }
        }
    }

    private func section(title: String, links: [IdeaLink], isProposal: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(isProposal ? Theme.Palette.ember : Theme.Palette.inkMuted)
                .tracking(0.6)

            if isProposal {
                ForEach(links) { link in
                    if let other = link.other(than: idea) {
                        // Not a navigation link: the decision is the action here, and a row
                        // that both navigates and holds buttons is a row you tap by mistake.
                        ConnectionRow(link: link, other: other, from: idea)
                    }
                }
            } else {
                // Confirmed connections read sideways. Vertically they push the status
                // control off the screen on any idea with more than two, and the thing you
                // want at a glance is *how many* and *of what kind* — which a row answers
                // and a column buries.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: Theme.Space.xs) {
                        ForEach(links) { link in
                            if let other = link.other(than: idea) {
                                NavigationLink {
                                    IdeaDetailView(idea: other)
                                } label: {
                                    ConnectionCard(link: link, other: other, from: idea)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 2)
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

            HStack(spacing: Theme.Space.xs) {
                    Button {
                        withAnimation(Theme.Motion.standard) { link.accept() }
                    } label: {
                        Text("Connect")
                            .font(Theme.Typography.control)
                            .foregroundStyle(Theme.Palette.canvas)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Theme.Palette.ember))
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(Theme.Motion.standard) { link.reject() }
                    } label: {
                        Text("Not related")
                            .font(Theme.Typography.control)
                            .foregroundStyle(Theme.Palette.inkMuted)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, 7)
                            .background(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
            }
            .padding(.top, Theme.Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.Palette.ember.opacity(0.35), lineWidth: 1)
        )
    }
}

/// A confirmed connection, as a card in a horizontal row.
///
/// Led by an icon in the other idea's Space colour, so a glance across the row tells you
/// which parts of your life this idea touches before you read a word of it.
private struct ConnectionCard: View {

    let link: IdeaLink
    let other: Idea
    let from: Idea

    private var accent: Color {
        other.category.flatMap { Color(hex: $0.colorHex) } ?? Theme.Palette.ember
    }

    private var relationshipLabel: String {
        let isSource = link.source?.id == from.id
        guard link.kind.isDirected, !isSource else { return link.kind.label }

        switch link.kind {
        case .prerequisiteFor: return "Unlocked by"
        case .buildsOn: return "Built on by"
        default: return link.kind.label
        }
    }

    private var strengthLabel: String {
        switch link.strength {
        case 0.7...: return "Strong"
        case 0.45..<0.7: return "Medium"
        default: return "Light"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack(spacing: Theme.Space.xs) {
                Image(systemName: other.category?.symbolName ?? link.kind.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(accent.opacity(0.16))
                    )

                Text(other.displayTitle)
                    .font(Theme.Typography.control)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(relationshipLabel)
                .font(Theme.Typography.meta)
                .foregroundStyle(accent)
                .padding(.horizontal, Theme.Space.xs)
                .padding(.vertical, 2)
                .background(Capsule().fill(accent.opacity(0.14)))

            Text(link.rationale)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(2)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // A segmented bar rather than pips: four filled of four reads as "strong"
            // faster than counting dots, and it gives the word underneath something to
            // agree with.
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Double(index) < (link.strength * 4).rounded() ? accent : Theme.Palette.hairline)
                        .frame(height: 3)
                }

                Text(strengthLabel)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .padding(.leading, 2)
            }
        }
        .frame(width: 210, alignment: .leading)
        .padding(Theme.Space.sm)
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
