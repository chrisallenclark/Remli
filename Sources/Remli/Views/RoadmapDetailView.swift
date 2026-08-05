import SwiftData
import SwiftUI

/// One goal and the route to it.
///
/// A step is an ordinary idea joined to the goal by a `prerequisiteFor` link — the same
/// relationship the model uses when it spots a dependency on its own. Building a roadmap by
/// hand and having one found for you therefore produce the same thing, which is the point:
/// the map, the connections and the roadmap all stay one graph rather than three parallel
/// records that can disagree.
struct RoadmapDetailView: View {

    @Bindable var goal: Idea

    @Environment(\.modelContext) private var context

    @Query(sort: \Idea.createdAt, order: .reverse)
    private var allIdeas: [Idea]

    @State private var isAddingStep = false

    private var accent: Color {
        goal.category.flatMap { Color(hex: $0.colorHex) } ?? Theme.Palette.ember
    }

    /// Ideas that must happen before the goal, in the order they were added.
    private var steps: [Idea] {
        var result: [Idea] = []
        for link in goal.incomingLinks ?? [] {
            guard
                link.isActive,
                link.kind == .prerequisiteFor,
                let source = link.source
            else { continue }
            result.append(source)
        }
        return result.sorted { $0.createdAt < $1.createdAt }
    }

    private var doneCount: Int {
        steps.filter { $0.status == .done }.count
    }

    /// Everything eligible to become a step: any other idea not already on this roadmap.
    private var candidates: [Idea] {
        let existing = Set(steps.map(\.id) + [goal.id])
        return allIdeas.filter { !existing.contains($0.id) && $0.kind == .idea }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                header
                progress

                stepsSection

                Spacer(minLength: Theme.Space.xxl)
            }
            .padding(.horizontal, Theme.Space.md)
            .padding(.top, Theme.Space.sm)
        }
        .background(Theme.Palette.canvas)
        .navigationTitle("Roadmap")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        isAddingStep = true
                    } label: {
                        Label("Add a step", systemImage: "plus")
                    }

                    Button(role: .destructive) {
                        goal.isGoal = false
                        goal.touch()
                    } label: {
                        Label("Stop pursuing this", systemImage: "flag.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isAddingStep) {
            StepPicker(goal: goal, candidates: candidates)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Label("GOAL", systemImage: "flag.fill")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(accent)
                .tracking(0.6)

            Text(goal.displayTitle)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let category = goal.category {
                CategoryChip(category: category, showsPath: true)
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack {
                Text(steps.isEmpty ? "No steps yet" : "\(doneCount) of \(steps.count) done")
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(Theme.Palette.ink)

                Spacer()

                if !steps.isEmpty {
                    Text("\(Int((Double(doneCount) / Double(steps.count)) * 100))%")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
            }

            // A single bar rather than a ring: it sits under a line of text and reads at a
            // glance without competing with the goal's title for attention.
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.hairline)
                    Capsule()
                        .fill(accent)
                        .frame(width: steps.isEmpty
                               ? 0
                               : proxy.size.width * (Double(doneCount) / Double(steps.count)))
                }
            }
            .frame(height: 5)
        }
        .cardBackground()
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("STEPS")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            if steps.isEmpty {
                Text("Nothing here yet. Add the ideas that have to happen before this one can — Remli will treat them as a route and show your progress along it.")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    NavigationLink {
                        IdeaDetailView(idea: step)
                    } label: {
                        StepRow(step: step, number: index + 1, accent: accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                isAddingStep = true
            } label: {
                Label("Add a step", systemImage: "plus")
                    .font(Theme.Typography.control)
                    .foregroundStyle(Theme.Palette.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Space.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.Palette.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StepRow: View {
    let step: Idea
    let number: Int
    let accent: Color

    private var isDone: Bool { step.status == .done }

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            ZStack {
                Circle()
                    .fill(isDone ? accent : Theme.Palette.surface)
                    .frame(width: 26, height: 26)
                Circle()
                    .strokeBorder(isDone ? Color.clear : Theme.Palette.hairline, lineWidth: 1)
                    .frame(width: 26, height: 26)

                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Palette.canvas)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Palette.inkMuted)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(step.displayTitle)
                    .font(Theme.Typography.ideaBody)
                    .foregroundStyle(isDone ? Theme.Palette.inkMuted : Theme.Palette.ink)
                    .strikethrough(isDone, color: Theme.Palette.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(step.status.label)
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

/// Choosing an existing idea to add as a step.
private struct StepPicker: View {

    let goal: Idea
    let candidates: [Idea]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var filtered: [Idea] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return candidates }
        return candidates.filter {
            $0.displayTitle.lowercased().contains(trimmed) || $0.text.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text(candidates.isEmpty
                         ? "Every other idea is already on this roadmap."
                         : "Nothing matches.")
                        .font(Theme.Typography.meta)
                        .foregroundStyle(Theme.Palette.inkMuted)
                } else {
                    ForEach(filtered) { idea in
                        Button {
                            add(idea)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(idea.displayTitle)
                                    .font(Theme.Typography.ideaBody)
                                    .foregroundStyle(Theme.Palette.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                if let category = idea.category {
                                    Text(category.displayPath)
                                        .font(Theme.Typography.meta)
                                        .foregroundStyle(Theme.Palette.inkMuted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $query, prompt: "Find an idea")
            .navigationTitle("Add a step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Joins the step to the goal with the same link type the model would use.
    ///
    /// Marked `origin: .user` and already accepted — a connection you drew yourself is not
    /// a suggestion and must never appear in the review queue asking for your approval.
    private func add(_ step: Idea) {
        let link = IdeaLink(
            source: step,
            target: goal,
            kind: .prerequisiteFor,
            rationale: "You added this as a step towards \(goal.displayTitle).",
            strength: 1,
            confidence: 1,
            origin: .user,
            reviewState: .accepted
        )
        context.insert(link)
        goal.touch()
        dismiss()
    }
}
