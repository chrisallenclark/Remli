import SwiftData
import SwiftUI

/// The importance score, shown and made arguable.
///
/// This number has decided what Remli pushes back at you since the first build, and until
/// now it has never appeared anywhere in the app. That is the widest gap between what the
/// app claims and what you can actually see: a ranking you cannot inspect is indistinguishable
/// from no ranking at all, and a wrong one you cannot fix is worse than either.
///
/// Two rules hold the design together. **The guess stays on screen after you disagree** —
/// showing it only until you touch it would answer the easy half of "let me see what it
/// assumed", and it is the only way to ever learn whether the model is any good at this.
/// And **changing it has to change something**, or the control is a placebo; resurfacing and
/// node size both read `Idea.importance`, so it does.
struct ImportanceControl: View {

    @Bindable var idea: Idea

    private var current: ImportanceLevel { idea.importanceLevel }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {

            HStack(alignment: .firstTextBaseline) {
                Text("IMPORTANCE")
                    .font(.system(.caption2, design: .monospaced))
                    .kerning(1.1)
                    .foregroundStyle(Theme.Palette.inkMuted)

                Spacer()

                // The raw figure, small and out of the way. You asked to see the score, and
                // some of the time the number is the thing you want — but leading with it
                // would turn a judgement into a dial reading.
                Text(String(format: "%.2f", idea.importance))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.Palette.ember)
            }

            HStack(spacing: Theme.Space.xxs) {
                ForEach(ImportanceLevel.allCases) { level in
                    levelButton(level)
                }
            }

            provenance

            Divider()
                .overlay(Theme.Palette.hairline)

            Text(current.effect)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted.opacity(0.8))
        }
        .cardBackground()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(
                    idea.importanceIsUserSet
                        ? Theme.Palette.ember.opacity(0.45)
                        : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func levelButton(_ level: ImportanceLevel) -> some View {
        let index = ImportanceLevel.allCases.firstIndex(of: level) ?? 0
        let selected = ImportanceLevel.allCases.firstIndex(of: current) ?? 0

        return Button {
            withAnimation(Theme.Motion.standard) {
                // Tapping the level you are already on clears back to the guess, so there
                // is always a way out that does not require finding the revert link.
                idea.setImportance(level == current && idea.importanceIsUserSet ? nil : level)
            }
        } label: {
            VStack(spacing: 6) {
                Capsule()
                    .fill(fill(for: index, selected: selected))
                    .frame(height: 5)

                Text(level.name)
                    .font(.system(size: 10, weight: index == selected ? .semibold : .regular))
                    .foregroundStyle(
                        index == selected ? Theme.Palette.ink : Theme.Palette.inkMuted
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.name). \(level.effect)")
        .accessibilityAddTraits(index == selected ? [.isSelected] : [])
    }

    /// Filled up to the chosen level, so the row reads as a meter rather than four
    /// unrelated buttons — which is what makes "more" and "less" obvious without a legend.
    private func fill(for index: Int, selected: Int) -> Color {
        if index == selected { return Theme.Palette.ember }
        if index < selected { return Theme.Palette.ember.opacity(0.34) }
        return Theme.Palette.hairline
    }

    @ViewBuilder
    private var provenance: some View {
        if idea.importanceIsUserSet {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                // Deliberately plain text rather than markdown emphasis: the bold would
                // depend on `LocalizedStringKey` parsing an interpolated literal, and a
                // silently unstyled asterisk pair is a worse outcome than no emphasis.
                Text(verbatim: "You set this. Remli guessed \(idea.importanceGuessLevel.name.lowercased()) — \(String(format: "%.2f", idea.importanceScore)).")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)

                Spacer(minLength: 0)

                Button {
                    withAnimation(Theme.Motion.standard) { idea.setImportance(nil) }
                } label: {
                    Text("Use the guess")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.ember)
                }
                .buttonStyle(.plain)
            }
        } else if idea.isEnriched {
            Text("Remli's guess. Tap a level to change it.")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
        } else {
            Text("Not judged yet — set it yourself, or wait for Remli to read it.")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
        }
    }
}
