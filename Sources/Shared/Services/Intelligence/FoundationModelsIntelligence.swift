import Foundation
import FoundationModels

/// Enrichment using Apple's on-device model.
///
/// This is the default. It costs nothing, works on a plane, and no idea ever leaves the
/// phone — which is also why it needs no consent screen, unlike the optional Claude
/// provider.
///
/// Output shape is enforced by `@Generable`: the framework constrains decoding at the
/// token level, so the model *cannot* return malformed JSON or a field of the wrong type.
/// That removes the entire class of parsing and repair code these integrations usually need.
struct FoundationModelsIntelligence: IdeaIntelligence {

    var displayName: String { "On-device (Apple Intelligence)" }

    var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Why the model is unavailable, for Settings to explain rather than just grey out.
    static var unavailabilityReason: String? {
        guard case .unavailable(let reason) = SystemLanguageModel.default.availability else {
            return nil
        }
        switch reason {
        case .deviceNotEligible:
            return "This iPhone doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is turned off. Enable it in Settings to let Remli file ideas automatically."
        case .modelNotReady:
            return "Apple Intelligence is still downloading. Remli will start filing ideas once it's ready."
        @unknown default:
            return "Apple Intelligence isn't available right now."
        }
    }

    // MARK: - Generation

    /// Constraining the symbol to a fixed list at generation time is the difference
    /// between a category that always has an icon and one that sometimes renders blank.
    /// The model physically cannot emit a value outside this set.
    @Generable
    struct Draft {

        @Guide(description: "True only if this is a chore or errand to tick off, like 'call the dentist'. False for anything exploratory, creative or worth developing.")
        var isQuickTask: Bool

        @Guide(description: "A short noun phrase naming the idea. Three to seven words. No trailing punctuation, no quotes.")
        var title: String

        @Guide(description: "One or two words. Broad enough that many future ideas could share it. Prefer an existing category when one fits.")
        var category: String

        @Guide(description: "An icon suiting the category.", .anyOf([
            "lightbulb", "paintbrush", "hammer", "chart.line.uptrend.xyaxis",
            "book", "heart", "figure.run", "dollarsign.circle",
            "person.2", "house", "airplane", "music.note",
            "camera", "gearshape", "leaf", "brain",
            "briefcase", "graduationcap", "fork.knife", "gamecontroller",
        ]))
        var symbol: String

        @Guide(description: "Two to four single-word lowercase tags drawn from the thought itself.", .maximumCount(4))
        var tags: [String]

        @Guide(description: "How much this seems to matter to the person who wrote it. 1 is a passing remark, 5 is something they clearly care about.", .range(1...5))
        var importance: Int

        @Guide(description: "Rough minutes of focused work to make a first meaningful dent in this. Not the whole project.", .range(5...480))
        var estimatedMinutes: Int
    }

    private static let instructions = """
        You file captured thoughts for someone's personal idea journal.

        Be literal. Describe only what is actually in the text — never invent detail, \
        never embellish, never assume a domain that wasn't mentioned. If a thought is \
        vague, a vague title is the correct answer.
        """

    func enrich(text: String, existingCategories: [String]) async throws -> IdeaEnrichment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntelligenceError.emptyInput }
        guard isAvailable else { throw IntelligenceError.unavailable }

        // A fresh session per enrichment. These are independent one-shot calls, so
        // carrying a transcript between them would only burn context and eventually
        // throw `exceededContextWindowSize` for no benefit.
        let session = LanguageModelSession(instructions: Self.instructions)

        let draft: Draft
        do {
            let response = try await session.respond(
                to: Self.prompt(for: trimmed, existingCategories: existingCategories),
                generating: Draft.self,
                // Low temperature: filing should be stable. The same thought captured
                // twice should not land in two different categories.
                options: GenerationOptions(temperature: 0.3)
            )
            draft = response.content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // A single capture longer than the context window. Retry on a truncated
            // version rather than giving up — the opening is usually the substance.
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: String(trimmed.prefix(2000)), existingCategories: existingCategories),
                generating: Draft.self,
                options: GenerationOptions(temperature: 0.3)
            )
            draft = response.content
        }

        return draft.normalized(fallbackTitle: trimmed)
    }

    private static func prompt(for text: String, existingCategories: [String]) -> String {
        var prompt = ""

        if !existingCategories.isEmpty {
            // Listing what already exists is what stops the category set fragmenting into
            // "Business", "business ideas" and "Biz" over a few weeks.
            let list = existingCategories.prefix(24).joined(separator: ", ")
            prompt += """
                Categories already in use: \(list)
                Reuse one of these exactly if it fits. Invent a new one only if none do.


                """
        }

        prompt += """
            Thought:
            \(text)
            """

        return prompt
    }

    // MARK: - Connections

    @Generable
    struct LinkDraft {

        @Guide(description: "The number of the related idea, taken from the numbered list.", .range(1...12))
        var ideaNumber: Int

        @Guide(description: "How the new idea relates to that one.", .anyOf([
            "relatesTo", "buildsOn", "prerequisiteFor", "variantOf", "contradicts",
        ]))
        var relationship: String

        @Guide(description: "One sentence, at most twenty words, naming the specific thing the two share. Refer to concrete details from both. Never say they are 'related' or 'similar' without saying how.")
        var reason: String

        @Guide(description: "1 means a tenuous stretch, 5 means they are obviously the same thread of thinking.", .range(1...5))
        var strength: Int
    }

    @Generable
    struct LinkJudgement {
        @Guide(description: "Only genuinely meaningful connections. Most pairs of ideas are unrelated, so returning an empty list is normal and correct.", .maximumCount(4))
        var links: [LinkDraft]
    }

    private static let connectionInstructions = """
        You find real relationships between someone's captured ideas.

        You are strict. A shared topic is not a relationship. Two ideas are connected only \
        if knowing one would genuinely change how the person thinks about or acts on the \
        other. When in doubt, leave it out — a wrong connection costs far more trust than \
        a missed one.

        Relationship meanings:
        - prerequisiteFor: the new idea must happen before the other one can
        - buildsOn: the new idea extends or elaborates the other
        - variantOf: another approach to the same underlying goal
        - contradicts: acting on both is inconsistent
        - relatesTo: genuinely same territory, but none of the above
        """

    func judgeConnections(
        source: IdeaSummary,
        candidates: [IdeaSummary]
    ) async throws -> [ProposedLink] {
        guard isAvailable else { throw IntelligenceError.unavailable }
        guard !candidates.isEmpty else { return [] }

        let shortlist = Array(candidates.prefix(12))

        var prompt = "New idea:\n\(source.title)\n\(source.excerpt)\n\nExisting ideas:\n"
        for (offset, candidate) in shortlist.enumerated() {
            prompt += "\(offset + 1). \(candidate.title) — \(candidate.excerpt)\n"
        }

        let session = LanguageModelSession(instructions: Self.connectionInstructions)
        let response = try await session.respond(
            to: prompt,
            generating: LinkJudgement.self,
            options: GenerationOptions(temperature: 0.2)
        )

        var seen = Set<UUID>()
        var results: [ProposedLink] = []

        for draft in response.content.links {
            // The range guide constrains this to 1...12, but the shortlist may be
            // shorter than twelve, so the bound still has to be checked.
            let index = draft.ideaNumber - 1
            guard shortlist.indices.contains(index) else { continue }

            let target = shortlist[index]
            guard seen.insert(target.id).inserted else { continue }

            let reason = draft.reason.trimmingCharacters(in: .whitespacesAndNewlines)
            // A link whose explanation is missing or vacuous is not worth showing.
            guard reason.count >= 12 else { continue }

            results.append(
                ProposedLink(
                    targetID: target.id,
                    kind: LinkKind(rawValue: draft.relationship) ?? .relatesTo,
                    rationale: reason,
                    strength: (Double(draft.strength) - 1) / 4
                )
            )
        }

        return results
    }

    /// Warms the model so the first real enrichment isn't paying for cold start.
    /// Called when the capture sheet opens, since a capture almost always follows.
    static func prewarm() {
        guard case .available = SystemLanguageModel.default.availability else { return }
        LanguageModelSession(instructions: instructions).prewarm()
    }

    // MARK: - Working an idea forward

    // Two calls, each with exactly one array, declared here beside the shapes that already
    // work in production.
    //
    // The first version asked for a restatement, steps and questions in one response with
    // two arrays in a single @Generable. It compiled and then failed at runtime every time,
    // falling silently through to the heuristic — which is why the questions never changed
    // no matter what the idea said. Mirroring `LinkJudgement`, which has worked since the
    // day it shipped, is worth more than saving a round trip.

    @Generable
    struct QuestionSet {
        @Guide(description: "Questions whose answers would genuinely unblock this idea. Ask about what cannot be known from the text: who exactly it is for, the cheapest way to test it, what would make it fail, what is being assumed. Never ask something the idea already answers.", .maximumCount(4))
        var questions: [String]
    }

    @Generable
    struct StepDraft {
        @Guide(description: "An action starting with a verb, under ten words, specific enough that it could not have been written about a different idea.")
        var title: String

        @Guide(description: "One short sentence on why this comes now rather than later.")
        var reason: String
    }

    @Generable
    struct StepSet {
        @Guide(description: "Concrete things to do next, smallest first, each doable in an afternoon. If it is unclear what the idea actually is, return an empty list rather than guessing.", .maximumCount(5))
        var steps: [StepDraft]
    }

    func developIdea(
        _ idea: IdeaSummary,
        related: [IdeaSummary],
        avoiding rejected: [String]
    ) async throws -> IdeaDevelopment {
        guard isAvailable else { throw IntelligenceError.unavailable }

        let context = Self.developmentContext(for: idea, related: related, avoiding: rejected)

        // Questions first, and they are the part that must not fail: they assume nothing
        // about the idea, so they stay useful even when the model only half understands it.
        // Steps are attempted separately and allowed to come back empty.
        let questionSet = try await LanguageModelSession(instructions: Self.questionInstructions)
            .respond(
                to: context,
                generating: QuestionSet.self,
                options: GenerationOptions(temperature: 0.8)
            ).content

        let questions = questionSet.questions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var steps: [DevelopmentStep] = []
        if let stepSet = try? await LanguageModelSession(instructions: Self.stepInstructions)
            .respond(
                to: context,
                generating: StepSet.self,
                options: GenerationOptions(temperature: 0.6)
            ).content {
            steps = stepSet.steps
                .map {
                    DevelopmentStep(
                        title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                        reason: $0.reason.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .filter { !$0.title.isEmpty }
        }

        guard !questions.isEmpty || !steps.isEmpty else {
            throw IntelligenceError.unusableResult
        }

        return IdeaDevelopment(restatement: idea.title, steps: steps, questions: questions)
    }

    /// One more question, for when a proposed one misses.
    func anotherQuestion(
        for idea: IdeaSummary,
        related: [IdeaSummary],
        avoiding existing: [String]
    ) async throws -> String {
        guard isAvailable else { throw IntelligenceError.unavailable }

        let set = try await LanguageModelSession(instructions: Self.questionInstructions)
            .respond(
                to: Self.developmentContext(for: idea, related: related, avoiding: existing),
                generating: QuestionSet.self,
                // Hotter than the first pass on purpose: the previous question was
                // rejected, so the most probable next one is a rephrasing of it.
                options: GenerationOptions(temperature: 1.0)
            ).content

        guard
            let question = set.questions
                .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty })
        else { throw IntelligenceError.unusableResult }

        return question
    }

    private static let questionInstructions = """
        You ask the questions that would move someone's own idea forward.

        Some ideas are three words long or named with a joke. If you cannot tell what the \
        thing actually is, ask that first — "what would this actually involve day to day?" \
        is worth more than four confident questions about a business you invented.

        Every question must be answerable in a sentence, and answering it must change what \
        they do next. Never ask anything the idea already answers, and never ask something \
        you could have asked about any idea at all.
        """

    private static let stepInstructions = """
        You propose the next concrete actions on someone's own idea.

        Each step is an action starting with a verb, doable in an afternoon, and specific \
        enough that it could not have been written about a different idea.

        Never suggest research, brainstorming, validation, or "define your goals". If you \
        cannot tell what the idea actually is, return no steps at all — a confident step \
        built on a guess is worse than an empty list, because they will follow it.
        """

    private static func developmentContext(
        for idea: IdeaSummary,
        related: [IdeaSummary],
        avoiding rejected: [String]
    ) -> String {
        var prompt = "The idea:\n\(idea.title)\n\(idea.excerpt)"

        // Everything cheap that disambiguates a short or oddly-named idea. Without this the
        // model reads a pun with no context and fills the gap with invention.
        if let space = idea.spaceName {
            prompt += "\n\nFiled under: \(space)"
        }
        if !idea.tags.isEmpty {
            prompt += "\nTagged: \(idea.tags.joined(separator: ", "))"
        }

        if !related.isEmpty {
            let list = related.prefix(6)
                .map { "- \($0.title): \($0.excerpt)" }
                .joined(separator: "\n")
            prompt += "\n\nOther ideas of theirs that connect to this:\n\(list)"
        }

        if !rejected.isEmpty {
            // The learning loop. Dismissals are the only signal given for free, and
            // repeating something already rejected is the fastest way to teach someone
            // that the feature is not listening.
            let list = rejected.suffix(12).map { "- \($0)" }.joined(separator: "\n")
            prompt += "\n\nAlready rejected — do not repeat these or anything close to them:\n\(list)"
        }

        return prompt
    }
}

// MARK: - Normalisation

private extension FoundationModelsIntelligence.Draft {

    /// Guided generation guarantees the *shape* of the output, not its taste. This is
    /// where a technically-valid-but-scruffy result gets tidied.
    func normalized(fallbackTitle: String) -> IdeaEnrichment {
        IdeaEnrichment(
            kind: isQuickTask ? .task : .idea,
            title: Self.cleanTitle(title, fallback: fallbackTitle),
            categoryName: Self.cleanCategory(category),
            categorySymbol: symbol,
            tags: Self.cleanTags(tags),
            importance: (Double(importance) - 1) / 4,
            estimatedMinutes: estimatedMinutes
        )
    }

    static func cleanTitle(_ raw: String, fallback: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”.,;:"))

        guard !title.isEmpty else {
            return String(fallback.prefix(60))
        }
        return title.count <= 80 ? title : String(title.prefix(80))
    }

    static func cleanCategory(_ raw: String) -> String {
        let category = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”.,;:"))

        guard !category.isEmpty else { return "Unfiled" }

        // Title-case single words so "business" and "Business" never coexist.
        return category.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    static func cleanTags(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for tag in raw {
            let cleaned = tag
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#\"'.,;:"))
                .lowercased()

            guard !cleaned.isEmpty, cleaned.count <= 24, seen.insert(cleaned).inserted else { continue }
            result.append(cleaned)
        }

        return Array(result.prefix(4))
    }
}
