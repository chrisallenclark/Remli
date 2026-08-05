import SwiftData
import SwiftUI

/// Working an idea forward.
///
/// Every other screen in Remli is for *looking at* ideas — reading them, filing them,
/// seeing how they connect. This is the only one for **doing something to one**. It is the
/// difference between a library and a workshop, and it is where an idea stops being a
/// sentence you once said and starts being a thing with steps.
///
/// Two kinds of output, deliberately:
///
/// - **Steps** are the model's guess at what to do. It does not know your circumstances, so
///   some will be wrong, which is why every one is dismissible and none are added without a
///   tap.
/// - **Questions** make no assumptions at all. Answering one turns your own answer into a
///   step — which was always going to be the better step, because you know things the model
///   never will.
///
/// Nothing here writes to the roadmap on its own.
struct WorkshopView: View {

    @Bindable var idea: Idea

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var development: IdeaDevelopment?
    @State private var isThinking = false
    @State private var failed = false

    /// Steps already added this session, so the list can show what has landed rather than
    /// silently removing rows and leaving you unsure whether the tap registered.
    @State private var addedStepIDs: Set<UUID> = []
    @State private var dismissedStepIDs: Set<UUID> = []

    /// Answers in progress, keyed by question.
    @State private var answers: [String: String] = [:]
    @State private var answeredQuestions: Set<String> = []

    private var accent: Color {
        idea.category.flatMap { Color(hex: $0.colorHex) } ?? Theme.Palette.ember
    }

    /// Ideas already connected to this one — the material a session gets to work with.
    private var related: [Idea] {
        idea.allLinks
            .filter(\.isActive)
            .compactMap { $0.other(than: idea) }
            .filter { $0.kind == .idea }
    }

    /// Steps already on the roadmap, so a session does not propose what is already there.
    private var existingStepTitles: Set<String> {
        var result = Set<String>()
        for link in idea.incomingLinks ?? [] where link.isActive && link.kind == .prerequisiteFor {
            if let title = link.source?.displayTitle.lowercased() { result.insert(title) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.lg) {
                    if isThinking {
                        thinking
                    } else if let development {
                        content(development)
                    } else if failed {
                        unavailable
                    }

                    Spacer(minLength: Theme.Space.xl)
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.sm)
            }
            .background(Theme.Palette.canvas)
            .navigationTitle("Work on this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await think() }
    }

    // MARK: - States

    private var thinking: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(idea.displayTitle)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Space.xs) {
                ProgressView()
                Text(related.isEmpty
                     ? "Thinking this through…"
                     : "Thinking this through, using \(related.count) connected idea\(related.count == 1 ? "" : "s")…")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(Theme.Palette.inkMuted)
            }
            .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xl)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(idea.displayTitle)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Remli couldn't work this one through just now. That's usually the on-device model being busy or unavailable — your idea is untouched, and trying again in a moment normally works.")
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await think() }
            } label: {
                Text("Try again")
                    .font(Theme.Typography.control)
                    .foregroundStyle(Theme.Palette.canvas)
                    .padding(.horizontal, Theme.Space.lg)
                    .padding(.vertical, Theme.Space.sm)
                    .background(Capsule().fill(Theme.Palette.ember))
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.Space.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Space.xl)
    }

    @ViewBuilder
    private func content(_ development: IdeaDevelopment) -> some View {
        // The idea, said back plainly.
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(development.restatement)
                .font(Theme.Typography.display)
                .foregroundStyle(Theme.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !related.isEmpty {
                Text("Built on \(related.count) idea\(related.count == 1 ? "" : "s") you've already had")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(accent)
            }
        }

        if !related.isEmpty {
            materialSection
        }

        let liveSteps = development.steps.filter { !dismissedStepIDs.contains($0.id) }
        if !liveSteps.isEmpty {
            stepsSection(liveSteps)
        }

        if !development.questions.isEmpty {
            questionsSection(development.questions)
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("WHAT YOU ALREADY HAVE")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.xs) {
                    ForEach(related) { other in
                        Text(other.displayTitle)
                            .font(Theme.Typography.meta)
                            .foregroundStyle(Theme.Palette.ink)
                            .lineLimit(2)
                            .frame(width: 150, alignment: .leading)
                            .padding(Theme.Space.xs)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .fill(Theme.Palette.surface)
                            )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func stepsSection(_ steps: [DevelopmentStep]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("STEPS YOU COULD TAKE")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            ForEach(steps) { step in
                StepProposal(
                    step: step,
                    accent: accent,
                    isAdded: addedStepIDs.contains(step.id),
                    isDuplicate: existingStepTitles.contains(step.title.lowercased()),
                    onAdd: { add(title: step.title, because: step.reason, id: step.id) },
                    onDismiss: { _ = dismissedStepIDs.insert(step.id) }
                )
            }
        }
    }

    private func questionsSection(_ questions: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text("WORTH ANSWERING")
                .font(Theme.Typography.sectionLabel)
                .foregroundStyle(Theme.Palette.inkMuted)
                .tracking(0.6)

            ForEach(questions, id: \.self) { question in
                QuestionPrompt(
                    question: question,
                    accent: accent,
                    answer: Binding(
                        get: { answers[question] ?? "" },
                        set: { answers[question] = $0 }
                    ),
                    isAnswered: answeredQuestions.contains(question),
                    onSubmit: { answer in
                        add(title: answer, because: question, id: UUID())
                        answeredQuestions.insert(question)
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func think() async {
        isThinking = true
        failed = false

        let summary = IdeaSummary(idea)
        // Closure rather than `map(IdeaSummary.init)`: the initialiser takes an excerpt
        // limit with a default, and a bare function reference resolves to the full
        // two-argument form, where defaults do not apply.
        let relatedSummaries = related.map { IdeaSummary($0) }
        let intelligence = IntelligenceFactory.make()

        do {
            development = try await intelligence.developIdea(summary, related: relatedSummaries)
        } catch {
            failed = true
        }

        isThinking = false
    }

    /// Writes a step onto the roadmap.
    ///
    /// A step is a `task`, not an idea — it belongs on the roadmap, not in the idea library,
    /// and tasks are already excluded from the Map and from categories. It joins the goal
    /// with the same `prerequisiteFor` link the model uses when it spots a dependency, so
    /// the roadmap, the graph and the connections stay one thing.
    ///
    /// Marking the idea a goal here is the one implicit action in the session, and it is
    /// justified: adding a step to something is the clearest possible statement that you
    /// intend to build it.
    private func add(title: String, because reason: String, id: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let step = Idea(text: trimmed)
        step.title = trimmed
        step.kind = .task
        step.isEnriched = true
        step.category = idea.category
        context.insert(step)

        let link = IdeaLink(
            source: step,
            target: idea,
            kind: .prerequisiteFor,
            rationale: reason,
            strength: 1,
            confidence: 1,
            origin: .user,
            reviewState: .accepted
        )
        context.insert(link)

        if !idea.isGoal {
            idea.isGoal = true
            if idea.status == .seed { idea.status = .active }
        }
        idea.touch()

        addedStepIDs.insert(id)
    }
}

// MARK: - Rows

private struct StepProposal: View {

    let step: DevelopmentStep
    let accent: Color
    let isAdded: Bool
    let isDuplicate: Bool
    var onAdd: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xxs) {
            Text(step.title)
                .font(Theme.Typography.ideaBody)
                .foregroundStyle(Theme.Palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(step.reason)
                .font(Theme.Typography.meta)
                .foregroundStyle(Theme.Palette.inkMuted)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if isAdded {
                Label("Added to the roadmap", systemImage: "checkmark")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(accent)
                    .padding(.top, Theme.Space.xxs)
            } else {
                HStack(spacing: Theme.Space.xs) {
                    Button(action: onAdd) {
                        Text(isDuplicate ? "Add anyway" : "Add step")
                            .font(Theme.Typography.control)
                            .foregroundStyle(Theme.Palette.canvas)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)

                    Button(action: onDismiss) {
                        Text("Not this")
                            .font(Theme.Typography.control)
                            .foregroundStyle(Theme.Palette.inkMuted)
                            .padding(.horizontal, Theme.Space.md)
                            .padding(.vertical, 7)
                            .background(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    if isDuplicate {
                        Text("already on the roadmap")
                            .font(Theme.Typography.meta)
                            .foregroundStyle(Theme.Palette.inkMuted)
                    }
                }
                .padding(.top, Theme.Space.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

/// A question, and the field that turns your answer into a step.
private struct QuestionPrompt: View {

    let question: String
    let accent: Color
    @Binding var answer: String
    let isAnswered: Bool
    var onSubmit: (String) -> Void

    private var trimmed: String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(question)
                .font(Theme.Typography.ideaBody)
                .foregroundStyle(Theme.Palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if isAnswered {
                Label("Added to the roadmap", systemImage: "checkmark")
                    .font(Theme.Typography.meta)
                    .foregroundStyle(accent)
            } else {
                HStack(spacing: Theme.Space.xs) {
                    TextField("Your answer becomes a step", text: $answer, axis: .vertical)
                        .font(Theme.Typography.meta)
                        .lineLimit(1...4)
                        .submitLabel(.done)

                    Button {
                        onSubmit(trimmed)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(trimmed.isEmpty ? Theme.Palette.hairline : accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmed.isEmpty)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
