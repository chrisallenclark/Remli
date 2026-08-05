import SwiftUI

struct IdeaRowView: View {

    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {

            HStack(alignment: .firstTextBaseline, spacing: Theme.Space.xs) {
                Text(idea.displayTitle)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(Theme.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: Theme.Space.xs)

                if idea.pinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Palette.ember)
                }
            }

            HStack(spacing: Theme.Space.xs) {
                if let category = idea.category {
                    CategoryChip(category: category)
                } else if !idea.isEnriched {
                    // Enrichment runs after capture, so an idea legitimately has no
                    // category for a moment. Saying so is better than showing a blank.
                    Label("Filing…", systemImage: "ellipsis")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }

                if idea.kind == .task {
                    Label(IdeaKind.task.label, systemImage: IdeaKind.task.symbolName)
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }

                Spacer(minLength: 0)

                Text(idea.createdAt, format: .relative(presentation: .named))
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

struct CategoryChip: View {
    let category: IdeaCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.symbolName)
                .font(.system(size: 10, weight: .medium))
            Text(category.name)
                .font(Theme.Typography.meta)
        }
        .foregroundStyle(Color(hex: category.colorHex) ?? Theme.Palette.ember)
        .padding(.horizontal, Theme.Space.xs)
        .padding(.vertical, 3)
        .background(
            Capsule().fill((Color(hex: category.colorHex) ?? Theme.Palette.ember).opacity(0.12))
        )
    }
}

extension Color {
    /// Parses `RRGGBB`. Returns nil rather than a default so callers decide the fallback
    /// — a silently wrong colour is harder to notice than a missing one.
    init?(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}
